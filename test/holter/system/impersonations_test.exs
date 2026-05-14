defmodule Holter.System.ImpersonationsTest do
  use Holter.DataCase, async: true

  alias Holter.Identity
  alias Holter.System.Impersonations
  alias Holter.System.Models.AuditLog

  describe "start/2" do
    test "returns a plaintext session token for the target" do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, plaintext} = Impersonations.start(actor, target)
      assert is_binary(plaintext)
    end

    test "the returned token resolves to the target user" do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, plaintext} = Impersonations.start(actor, target)
      resolved = Identity.fetch_user_by_session_token(plaintext)
      assert resolved.id == target.id
    end

    test "emits an impersonate_start audit log entry" do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, _} = Impersonations.start(actor, target)
      [audit] = Repo.all(AuditLog)
      assert audit.action == "impersonate_start"
    end

    test "the audit log row is attributed to the acting admin" do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, _} = Impersonations.start(actor, target)
      [audit] = Repo.all(AuditLog)
      assert audit.actor_id == actor.user_id
    end

    test "the audit log row targets the impersonated user" do
      actor = admin_fixture()
      target = user_fixture()
      {:ok, _} = Impersonations.start(actor, target)
      [audit] = Repo.all(AuditLog)
      assert audit.resource == "User:" <> target.id
    end

    test "refuses self-impersonation" do
      actor = admin_fixture()
      assert {:error, :cannot_impersonate_self} = Impersonations.start(actor, actor.user)
    end
  end

  describe "stop/3" do
    test "emits an impersonate_end audit log entry" do
      admin = admin_fixture()
      target = user_fixture()
      {:ok, plaintext} = Impersonations.start(admin, target)
      Repo.delete_all(AuditLog)

      {:ok, :ok} = Impersonations.stop(target, admin.user, plaintext)

      [audit] = Repo.all(AuditLog)
      assert audit.action == "impersonate_end"
    end

    test "attributes the end event to the admin user" do
      admin = admin_fixture()
      target = user_fixture()
      {:ok, plaintext} = Impersonations.start(admin, target)
      Repo.delete_all(AuditLog)

      {:ok, :ok} = Impersonations.stop(target, admin.user, plaintext)

      [audit] = Repo.all(AuditLog)
      assert audit.actor_id == admin.user_id
    end

    test "deletes the target's session token" do
      admin = admin_fixture()
      target = user_fixture()
      {:ok, plaintext} = Impersonations.start(admin, target)

      assert Identity.fetch_user_by_session_token(plaintext)

      {:ok, :ok} = Impersonations.stop(target, admin.user, plaintext)

      refute Identity.fetch_user_by_session_token(plaintext)
    end
  end
end
