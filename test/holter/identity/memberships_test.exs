defmodule Holter.Identity.MembershipsTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Memberships
  alias Holter.Identity.WorkspaceMembership

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
  end
end
