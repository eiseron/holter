defmodule Holter.Monitoring.Policies.WorkspaceTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring.Models.Workspace
  alias Holter.Monitoring.Policies.Workspace, as: Policy

  describe ":read" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)

      assert :ok = Bodyguard.permit(Policy, :read, user, workspace)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :read, non_member_user(), workspace)
    end
  end

  describe ":create" do
    test "any authenticated user is permitted" do
      user = non_member_user()

      assert :ok = Bodyguard.permit(Policy, :create, user, nil)
    end
  end

  describe ":update" do
    test "admin is permitted" do
      {user, workspace} = workspace_with_role(:admin)

      assert :ok = Bodyguard.permit(Policy, :update, user, workspace)
    end

    test "member is forbidden" do
      {user, workspace} = workspace_with_role(:member)

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :update, user, workspace)
    end
  end

  describe ":delete" do
    test "owner is permitted" do
      {user, workspace} = workspace_with_role(:owner)

      assert :ok = Bodyguard.permit(Policy, :delete, user, workspace)
    end

    test "admin is forbidden" do
      {user, workspace} = workspace_with_role(:admin)

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :delete, user, workspace)
    end
  end

  describe "scope/2" do
    test "limits to workspaces the user is a member of" do
      {user, workspace} = workspace_with_role(:member)
      {_other, _other_workspace} = workspace_with_role(:owner)

      ids =
        Workspace
        |> Policy.scope(user)
        |> Holter.Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [workspace.id]
    end
  end
end
