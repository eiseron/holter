defmodule Holter.IntegrationsFixturesTest do
  use Holter.DataCase, async: true

  describe "integration_rule_fixture/1" do
    test "accepts integration_id atom key directly" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      rule =
        integration_rule_fixture(integration_id: integration.id, monitor_id: monitor.id)

      assert rule.integration_id == integration.id
    end

    test "accepts monitor_id atom key directly" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      rule =
        integration_rule_fixture(integration_id: integration.id, monitor_id: monitor.id)

      assert rule.monitor_id == monitor.id
    end

    test "accepts integration_id and monitor_id as string keys" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      rule =
        integration_rule_fixture(%{
          "integration_id" => integration.id,
          "monitor_id" => monitor.id
        })

      assert rule.integration_id == integration.id
    end

    test "raises ArgumentError when integration_id is missing" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      assert_raise ArgumentError, ~r/integration_id/, fn ->
        integration_rule_fixture(monitor: monitor)
      end
    end

    test "raises ArgumentError when monitor_id is missing" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert_raise ArgumentError, ~r/monitor_id/, fn ->
        integration_rule_fixture(integration: integration)
      end
    end
  end
end
