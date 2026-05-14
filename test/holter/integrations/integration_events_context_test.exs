defmodule Holter.Integrations.IntegrationEventsContextTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.IntegrationEventsContext
  alias Holter.Integrations.Models.IntegrationEvent

  describe "log_event!/1" do
    test "inserts an outbound success event" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      integration_id = integration.id
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      event =
        IntegrationEventsContext.log_event!(%{
          integration_id: integration.id,
          direction: :outbound,
          action: "pause_campaign",
          target: "campaign:gads-12345",
          status: :success,
          duration_ms: 150,
          occurred_at: now
        })

      assert %IntegrationEvent{
               integration_id: ^integration_id,
               direction: :outbound,
               action: "pause_campaign",
               status: :success
             } = event
    end

    test "inserts an inbound event with payload_redacted" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      event =
        IntegrationEventsContext.log_event!(%{
          integration_id: integration.id,
          direction: :inbound,
          action: "resolve_incident",
          payload_redacted: %{"incident_id" => "abc-123"},
          status: :success,
          occurred_at: now
        })

      assert %IntegrationEvent{
               direction: :inbound,
               payload_redacted: %{"incident_id" => "abc-123"}
             } = event
    end
  end

  describe "list_events/2" do
    test "returns events for the integration" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      _e1 =
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -60))

      _e2 = integration_event_fixture(integration: integration, occurred_at: now)

      assert length(IntegrationEventsContext.list_events(integration.id)) == 2
    end

    test "orders events by occurred_at desc" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      _e1 =
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -60))

      _e2 = integration_event_fixture(integration: integration, occurred_at: now)

      [first | _] = IntegrationEventsContext.list_events(integration.id)
      assert first.occurred_at == now
    end

    test "filters by status" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      _success =
        integration_event_fixture(integration: integration, status: :success, occurred_at: now)

      _failed =
        integration_event_fixture(
          integration: integration,
          status: :failed,
          occurred_at: DateTime.add(now, -1)
        )

      assert [%{status: :failed}] =
               IntegrationEventsContext.list_events(integration.id, status: :failed)
    end

    test "filters by direction" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      _out =
        integration_event_fixture(
          integration: integration,
          direction: :outbound,
          occurred_at: now
        )

      _in =
        integration_event_fixture(
          integration: integration,
          direction: :inbound,
          occurred_at: DateTime.add(now, -1)
        )

      assert [%{direction: :inbound}] =
               IntegrationEventsContext.list_events(integration.id, direction: :inbound)
    end

    test "does not return events from another integration" do
      ws = workspace_fixture()
      ig1 = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      ig2 = integration_fixture(workspace_id: ws.id, provider: :slack)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      _e1 = integration_event_fixture(integration: ig1, occurred_at: now)

      assert IntegrationEventsContext.list_events(ig2.id) == []
    end

    test "respects the limit option" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      results = IntegrationEventsContext.list_events(integration.id, limit: 3)
      assert length(results) == 3
    end
  end
end
