defmodule Holter.Monitoring.Policies.MonitorTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring.Models.Monitor
  alias Holter.Monitoring.Policies.Monitor, as: Policy

  describe ":system actor" do
    test "permits :delete on any monitor" do
      monitor = %Monitor{workspace_id: Ecto.UUID.generate()}

      assert :ok = Bodyguard.permit(Policy, :delete, :system, monitor)
    end
  end

  describe ":read" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert :ok = Bodyguard.permit(Policy, :read, user, monitor)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)
      outsider = non_member_user()

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :read, outsider, monitor)
    end
  end

  describe ":update" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert :ok = Bodyguard.permit(Policy, :update, user, monitor)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :update, non_member_user(), monitor)
    end
  end

  describe ":run_now" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert :ok = Bodyguard.permit(Policy, :run_now, user, monitor)
    end
  end

  describe ":delete" do
    test "admin is permitted" do
      {user, workspace} = workspace_with_role(:admin)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert :ok = Bodyguard.permit(Policy, :delete, user, monitor)
    end

    test "owner is permitted" do
      {user, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert :ok = Bodyguard.permit(Policy, :delete, user, monitor)
    end

    test "member is forbidden" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :delete, user, monitor)
    end
  end

  describe ":create with workspace subject" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)

      assert :ok = Bodyguard.permit(Policy, :create, user, workspace)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :create, non_member_user(), workspace)
    end
  end

  describe "scope/2" do
    test "limits to monitors in user-accessible workspaces" do
      {user, workspace} = workspace_with_role(:member)
      mine = monitor_fixture(workspace_id: workspace.id)
      {_other, other_workspace} = workspace_with_role(:owner)
      _theirs = monitor_fixture(workspace_id: other_workspace.id)

      ids =
        Monitor
        |> Policy.scope(user)
        |> Holter.Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mine.id]
    end
  end
end
