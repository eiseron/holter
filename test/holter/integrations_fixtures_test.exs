defmodule Holter.IntegrationsFixturesTest do
  use Holter.DataCase, async: true

  describe "integration_binding_fixture/1" do
    test "accepts integration_id atom key directly" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      binding =
        integration_binding_fixture(integration_id: integration.id, monitor_id: monitor.id)

      assert binding.integration_id == integration.id
    end

    test "accepts monitor_id atom key directly" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      binding =
        integration_binding_fixture(integration_id: integration.id, monitor_id: monitor.id)

      assert binding.monitor_id == monitor.id
    end

    test "accepts integration_id and monitor_id as string keys" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      binding =
        integration_binding_fixture(%{
          "integration_id" => integration.id,
          "monitor_id" => monitor.id
        })

      assert binding.integration_id == integration.id
    end

    test "raises ArgumentError when integration_id is missing" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      assert_raise ArgumentError, ~r/integration_id/, fn ->
        integration_binding_fixture(monitor: monitor)
      end
    end

    test "raises ArgumentError when monitor_id is missing" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert_raise ArgumentError, ~r/monitor_id/, fn ->
        integration_binding_fixture(integration: integration)
      end
    end
  end
end
