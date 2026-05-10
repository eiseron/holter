defmodule Holter.Monitoring.MonitorsAuthorizationTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring

  @valid_attrs %{
    url: "https://example.com",
    method: :get,
    interval_seconds: 60,
    timeout_seconds: 30
  }

  describe "create_monitor/2" do
    test "given a non-member, returns {:error, :forbidden}" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()
      attrs = Map.put(@valid_attrs, :workspace_id, workspace.id)

      assert {:error, :forbidden} = Monitoring.create_monitor(outsider, attrs)
    end

    test "given a member, succeeds" do
      {member, workspace} = workspace_with_role(:member)
      attrs = Map.put(@valid_attrs, :workspace_id, workspace.id)

      assert {:ok, _monitor} = Monitoring.create_monitor(member, attrs)
    end
  end

  describe "update_monitor/3" do
    test "given a non-member, returns {:error, :forbidden}" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:error, :forbidden} =
               Monitoring.update_monitor(outsider, monitor, %{url: "https://changed.example"})
    end

    test "given a member, succeeds" do
      {member, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:ok, _updated} =
               Monitoring.update_monitor(member, monitor, %{url: "https://changed.example"})
    end
  end

  describe "delete_monitor/2" do
    test "given a non-member, returns {:error, :forbidden}" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:error, :forbidden} = Monitoring.delete_monitor(outsider, monitor)
    end

    test "given a member (non-admin), returns {:error, :forbidden}" do
      {member, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:error, :forbidden} = Monitoring.delete_monitor(member, monitor)
    end

    test "given an admin, succeeds" do
      {admin, workspace} = workspace_with_role(:admin)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:ok, _deleted} = Monitoring.delete_monitor(admin, monitor)
    end

    test "given the workspace owner, succeeds" do
      {owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:ok, _deleted} = Monitoring.delete_monitor(owner, monitor)
    end
  end

  describe "get_monitor/2" do
    test "given a non-member, returns {:error, :not_found}" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:error, :not_found} = Monitoring.get_monitor(outsider, monitor.id)
    end

    test "given a member, returns {:ok, monitor}" do
      {member, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert {:ok, ^monitor} = Monitoring.get_monitor(member, monitor.id)
    end
  end

  describe "list_monitors_by_workspace/2" do
    test "given a non-member, returns []" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()
      _monitor = monitor_fixture(workspace_id: workspace.id)

      assert [] = Monitoring.list_monitors_by_workspace(outsider, workspace.id)
    end

    test "given a member, returns the workspace's monitors" do
      {member, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      result = Monitoring.list_monitors_by_workspace(member, workspace.id)

      assert Enum.map(result, & &1.id) == [monitor.id]
    end
  end

  describe "count_monitors/2" do
    test "given a non-member, returns 0" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()
      _monitor = monitor_fixture(workspace_id: workspace.id)

      assert Monitoring.count_monitors(outsider, workspace.id) == 0
    end
  end
end
