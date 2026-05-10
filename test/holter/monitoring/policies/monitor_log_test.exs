defmodule Holter.Monitoring.Policies.MonitorLogTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring.Models.MonitorLog
  alias Holter.Monitoring.Policies.MonitorLog, as: Policy

  describe ":read with parent monitor subject" do
    test "member of the parent workspace is permitted" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert :ok = Bodyguard.permit(Policy, :read, user, monitor)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :read, non_member_user(), monitor)
    end

    test ":system actor is permitted" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert :ok = Bodyguard.permit(Policy, :read, :system, monitor)
    end
  end

  describe "scope/2" do
    test "limits to logs whose monitor belongs to user workspaces" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)
      mine = log_fixture(monitor_id: monitor.id)

      {_other, other_workspace} = workspace_with_role(:owner)
      other_monitor = monitor_fixture(workspace_id: other_workspace.id)
      _theirs = log_fixture(monitor_id: other_monitor.id)

      ids =
        MonitorLog
        |> Policy.scope(user)
        |> Holter.Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mine.id]
    end
  end
end
