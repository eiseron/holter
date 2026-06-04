defmodule Holter.Integrations.EngineRLSTest do
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  import Holter.RLSHelpers, only: [setup_app_role: 0]

  alias Holter.Integrations.Engine
  alias Holter.Integrations.Workers.IntegrationDispatcher

  setup do
    user = user_fixture()
    workspace = workspace_fixture_for(user)
    monitor = monitor_fixture(workspace_id: workspace.id)
    integration = integration_fixture(workspace_id: workspace.id, status: :active)

    _rule =
      integration_rule_fixture(
        integration: integration,
        monitor: monitor,
        event_type: "incident_opened",
        action: "pause_campaign",
        target_id: "gads-rls"
      )

    stranger = user_fixture()
    stranger_ws = workspace_fixture_for(stranger)
    stranger_monitor = monitor_fixture(workspace_id: stranger_ws.id)
    stranger_integration = integration_fixture(workspace_id: stranger_ws.id, status: :active)

    _stranger_rule =
      integration_rule_fixture(
        integration: stranger_integration,
        monitor: stranger_monitor,
        event_type: "incident_opened",
        action: "pause_campaign",
        target_id: "gads-stranger"
      )

    setup_app_role()

    %{
      workspace: workspace,
      monitor: monitor,
      integration: integration,
      stranger_monitor: stranger_monitor
    }
  end

  describe "dispatch_event/2 under holter_app FORCE RLS" do
    test "enqueues a dispatch for the workspace's active integration", ctx do
      incident = %{
        id: Ecto.UUID.generate(),
        monitor_id: ctx.monitor.id,
        workspace_id: ctx.workspace.id
      }

      Engine.dispatch_event(incident, "incident_opened")

      assert_enqueued(
        worker: IntegrationDispatcher,
        args: %{"workspace_id" => ctx.workspace.id, "integration_id" => ctx.integration.id}
      )
    end

    test "a workspace's stamp cannot see another workspace's rules", ctx do
      incident = %{
        id: Ecto.UUID.generate(),
        monitor_id: ctx.stranger_monitor.id,
        workspace_id: ctx.workspace.id
      }

      Engine.dispatch_event(incident, "incident_opened")

      refute_enqueued(worker: IntegrationDispatcher)
    end
  end
end
