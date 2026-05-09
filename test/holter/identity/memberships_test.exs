defmodule Holter.Identity.MembershipsTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.ApiToken
  alias Holter.Identity.Memberships
  alias Holter.Identity.WorkspaceMembership
  alias Holter.Repo.Tenant

  describe "create_default_membership/2" do
    test "assigns the :owner role" do
      user = user_fixture()
      workspace = workspace_fixture()

      {:ok, membership} = Memberships.create_default_membership(user, workspace)

      assert membership.role == :owner
    end

    test "rejects a duplicate (user, workspace) pair" do
      user = user_fixture()
      workspace = workspace_fixture()

      {:ok, _} = Memberships.create_default_membership(user, workspace)
      {:error, changeset} = Memberships.create_default_membership(user, workspace)

      assert "is already a member of this workspace" in errors_on(changeset).user_id
    end

    test "lets the same user own two distinct workspaces" do
      user = user_fixture()
      workspace_a = workspace_fixture()
      workspace_b = workspace_fixture()

      {:ok, _} = Memberships.create_default_membership(user, workspace_a)

      assert {:ok, %WorkspaceMembership{}} =
               Memberships.create_default_membership(user, workspace_b)
    end
  end

  describe "member?/2" do
    test "is false before any membership is created" do
      refute Memberships.member?(user_fixture(), workspace_fixture())
    end

    test "is true once the membership is created" do
      user = user_fixture()
      workspace = workspace_fixture()
      {:ok, _} = Memberships.create_default_membership(user, workspace)

      assert Memberships.member?(user, workspace)
    end

    test "stays scoped: an outsider is not a member of someone else's workspace" do
      owner = user_fixture()
      outsider = user_fixture()
      workspace = workspace_fixture()
      {:ok, _} = Memberships.create_default_membership(owner, workspace)

      refute Memberships.member?(outsider, workspace)
    end
  end

  describe "owner?/2" do
    test "is true when the user holds the :owner role on the workspace" do
      user = user_fixture()
      workspace = workspace_fixture(owner: user)

      assert Memberships.owner?(user, workspace)
    end

    test "is false for a member with a non-owner role" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner: owner)
      {:ok, membership} = Memberships.create_default_membership(member, workspace)

      Tenant.with_user!(member, fn ->
        membership
        |> Ecto.Changeset.change(role: :member)
        |> Repo.update!()
      end)

      refute Memberships.owner?(member, workspace)
    end

    test "is false for a non-member" do
      outsider = user_fixture()
      workspace = workspace_fixture()

      refute Memberships.owner?(outsider, workspace)
    end
  end

  describe "list_workspaces_for_user/1" do
    test "returns nothing when the user owns no workspace" do
      assert Memberships.list_workspaces_for_user(user_fixture()) == []
    end

    test "returns every workspace the user belongs to" do
      user = user_fixture()
      ws_a = workspace_fixture(%{name: "Alpha"})
      ws_b = workspace_fixture(%{name: "Beta"})
      {:ok, _} = Memberships.create_default_membership(user, ws_a)
      {:ok, _} = Memberships.create_default_membership(user, ws_b)

      ids = user |> Memberships.list_workspaces_for_user() |> Enum.map(& &1.id) |> MapSet.new()

      assert MapSet.equal?(ids, MapSet.new([ws_a.id, ws_b.id]))
    end

    test "skips workspaces the user is not a member of" do
      user = user_fixture()
      _other_owner_workspace = workspace_fixture()

      assert Memberships.list_workspaces_for_user(user) == []
    end
  end

  describe "FK cascade behaviour" do
    test "deletes membership rows when their user is deleted" do
      user = user_fixture()
      workspace = workspace_fixture()
      {:ok, membership} = Memberships.create_default_membership(user, workspace)

      Repo.delete!(user)

      refute Repo.get(WorkspaceMembership, membership.id)
    end

    test "deletes membership rows when their workspace is deleted" do
      user = user_fixture()
      workspace = workspace_fixture()
      {:ok, membership} = Memberships.create_default_membership(user, workspace)

      Repo.delete!(workspace)

      refute Repo.get(WorkspaceMembership, membership.id)
    end

    test "revokes the user's api tokens when their membership is deleted (DB trigger)" do
      user = user_fixture()
      workspace = workspace_fixture(owner: user)
      {token, _plaintext} = api_token_fixture(user, workspace)

      [membership] =
        Tenant.with_user!(user, fn ->
          Repo.all(WorkspaceMembership)
          |> Enum.filter(&(&1.user_id == user.id and &1.workspace_id == workspace.id))
        end)

      Tenant.with_user!(user, fn -> Repo.delete!(membership) end)

      reloaded =
        Tenant.with_workspace!(workspace.id, fn -> Repo.get!(ApiToken, token.id) end)

      assert %DateTime{} = reloaded.revoked_at
    end
  end

  describe "admin?/2" do
    test "is true for the default :owner membership" do
      user = user_fixture()
      workspace = workspace_fixture()
      {:ok, _} = Memberships.create_default_membership(user, workspace)

      assert Memberships.admin?(user, workspace)
    end

    test "is true for an :admin role" do
      user = user_fixture()
      workspace = workspace_fixture()
      {:ok, m} = Memberships.create_default_membership(user, workspace)
      {:ok, _} = m |> Ecto.Changeset.change(role: :admin) |> Repo.update()

      assert Memberships.admin?(user, workspace)
    end

    test "is false for a :member role" do
      user = user_fixture()
      workspace = workspace_fixture()
      {:ok, m} = Memberships.create_default_membership(user, workspace)
      {:ok, _} = m |> Ecto.Changeset.change(role: :member) |> Repo.update()

      refute Memberships.admin?(user, workspace)
    end

    test "is false when no membership exists" do
      user = user_fixture()
      workspace = workspace_fixture()

      refute Memberships.admin?(user, workspace)
    end
  end

  describe "get_membership/2" do
    test "returns the membership row when it exists" do
      user = user_fixture()
      workspace = workspace_fixture()
      {:ok, created} = Memberships.create_default_membership(user, workspace)

      found = Memberships.get_membership(user, workspace)

      assert match?(%WorkspaceMembership{id: id, role: :owner} when id == created.id, found)
    end

    test "returns nil when there is no membership" do
      user = user_fixture()
      workspace = workspace_fixture()

      assert Memberships.get_membership(user, workspace) == nil
    end
  end

  describe "list_workspace_memberships_for_user/1" do
    test "returns every membership with the workspace preloaded and the role intact" do
      user = user_fixture()
      ws_a = workspace_fixture(owner: user, name: "A")
      ws_b = workspace_fixture(owner: user, name: "B")
      change_role!(user, ws_b, :member)

      summary =
        Memberships.list_workspace_memberships_for_user(user)
        |> Enum.map(fn m ->
          %Holter.Monitoring.Workspace{slug: slug} = m.workspace
          {slug, m.role}
        end)
        |> Enum.sort()

      assert summary == Enum.sort([{ws_a.slug, :owner}, {ws_b.slug, :member}])
    end
  end

  defp change_role!(user, workspace, role) do
    Memberships.get_membership(user, workspace)
    |> Ecto.Changeset.change(role: role)
    |> Repo.update!()
  end
end
