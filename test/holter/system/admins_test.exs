defmodule Holter.System.AdminsTest do
  use Holter.DataCase, async: true

  alias Holter.Repo
  alias Holter.System
  alias Holter.System.Admins
  alias Holter.System.Models.Admin
  alias Holter.System.Models.AuditLog

  describe "admin?/1" do
    test "returns false when the user has no admin row" do
      user = user_fixture()
      refute Admins.admin?(user)
    end

    test "returns false when the user's admin row has been revoked" do
      admin = admin_fixture()

      admin
      |> Admin.revocation_changeset(%{
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_by_admin_id: admin.id
      })
      |> Repo.update!()

      refute Admins.admin?(admin.user)
    end

    test "returns true when the user has an active admin row" do
      admin = admin_fixture()
      assert Admins.admin?(admin.user)
    end

    test "returns false for nil" do
      refute Admins.admin?(nil)
    end
  end

  describe "list_admins/0" do
    test "orders active admins newest promotion first" do
      _older = admin_fixture(%{promoted_at: ~U[2026-01-01 00:00:00Z]})
      newer = admin_fixture(%{promoted_at: ~U[2026-02-01 00:00:00Z]})

      [first | _] = Admins.list_admins()
      assert first.id == newer.id
    end

    test "excludes revoked admin rows" do
      anchor = admin_fixture()

      revoked =
        admin_fixture()
        |> Admin.revocation_changeset(%{
          revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
          revoked_by_admin_id: anchor.id
        })
        |> Repo.update!()

      ids = Admins.list_admins() |> Enum.map(& &1.id)
      refute revoked.id in ids
    end
  end

  describe "promote_user/2 success" do
    setup do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, promoted} = Admins.promote_user(target, actor)

      audit =
        AuditLog
        |> Ecto.Query.order_by([a], desc: a.occurred_at)
        |> Ecto.Query.first()
        |> Repo.one()

      %{actor: actor, target: target, promoted: promoted, audit: audit}
    end

    test "inserts an admins row for the target", %{target: target} do
      assert Admins.admin?(target)
    end

    test "records the promoting actor on the new admin row", %{actor: actor, promoted: promoted} do
      assert promoted.promoted_by_admin_id == actor.id
    end

    test "writes an audit log entry with the promote action", %{audit: audit} do
      assert audit.action == "promote_admin"
    end

    test "attributes the audit log to the actor's user", %{actor: actor, audit: audit} do
      assert audit.actor_id == actor.user_id
    end

    test "tags the audit log as an admin action", %{audit: audit} do
      assert audit.actor_type == "admin"
    end

    test "encodes the target id in the audit log diff", %{target: target, audit: audit} do
      assert audit.diff["target_user_id"] == target.id
    end

    test "encodes the target email in the audit log diff", %{target: target, audit: audit} do
      assert audit.diff["target_email"] == target.email
    end

    test "names the resource using the target id", %{target: target, audit: audit} do
      assert audit.resource == "User:" <> target.id
    end
  end

  describe "promote_user/2 conflict" do
    test "returns :already_admin when the target already holds the role" do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, _} = Admins.promote_user(target, actor)

      assert {:error, :already_admin} = Admins.promote_user(target, actor)
    end

    test "does not insert an audit row on conflict" do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, _} = Admins.promote_user(target, actor)
      count_before = Repo.aggregate(AuditLog, :count)

      Admins.promote_user(target, actor)

      assert Repo.aggregate(AuditLog, :count) == count_before
    end
  end

  describe "bootstrap_promote!/1" do
    test "promotes the first admin with a nil promoting admin reference" do
      target = user_fixture()
      admin = Admins.bootstrap_promote!(target)
      assert is_nil(admin.promoted_by_admin_id)
    end

    test "tags the bootstrap audit log as a system action" do
      target = user_fixture()
      Admins.bootstrap_promote!(target)

      [audit] = Repo.all(AuditLog)
      assert audit.actor_type == "system"
    end

    test "leaves actor_id null on the bootstrap audit log" do
      target = user_fixture()
      Admins.bootstrap_promote!(target)

      [audit] = Repo.all(AuditLog)
      assert is_nil(audit.actor_id)
    end

    test "raises when any admin already exists" do
      _existing = admin_fixture()
      target = user_fixture()

      assert_raise RuntimeError, ~r/bootstrap_promote!/, fn ->
        Admins.bootstrap_promote!(target)
      end
    end
  end

  describe "demote_admin/2 success" do
    setup do
      actor = admin_fixture()
      target_user = user_fixture()
      {:ok, target_admin} = Admins.promote_user(target_user, actor)
      {:ok, revoked} = Admins.demote_admin(target_admin, actor)
      %{actor: actor, target_user: target_user, revoked: revoked}
    end

    test "stamps revoked_at on the row", %{revoked: revoked} do
      refute is_nil(revoked.revoked_at)
    end

    test "records the revoking admin", %{actor: actor, revoked: revoked} do
      assert revoked.revoked_by_admin_id == actor.id
    end

    test "removes the target from the active admin set", %{target_user: target_user} do
      refute Admins.admin?(target_user)
    end

    test "writes a demote_admin audit log entry", %{target_user: target_user} do
      audit =
        AuditLog
        |> Ecto.Query.where([a], a.action == "demote_admin")
        |> Repo.one()

      assert audit.diff["target_user_id"] == target_user.id
    end
  end

  describe "demote_admin/2 guards" do
    test "refuses self-demotion" do
      actor = admin_fixture()
      assert {:error, :cannot_self_demote} = Admins.demote_admin(actor, actor)
    end

    test "leaves the self-demote candidate active" do
      actor = admin_fixture()
      Admins.demote_admin(actor, actor)
      assert Admins.admin?(actor.user)
    end

    test "refuses to demote an already-revoked admin" do
      actor = admin_fixture()
      target_user = user_fixture()
      {:ok, target_admin} = Admins.promote_user(target_user, actor)
      {:ok, _} = Admins.demote_admin(target_admin, actor)

      reloaded = Repo.reload!(target_admin)
      assert {:error, :already_revoked} = Admins.demote_admin(reloaded, actor)
    end
  end

  describe "facade Holter.System" do
    test "delegates admin?/1" do
      admin = admin_fixture()
      assert System.admin?(admin.user)
    end

    test "delegates promote_user/2" do
      actor = admin_fixture()
      target = user_fixture()
      assert {:ok, %Admin{}} = System.promote_user(target, actor)
    end
  end
end
