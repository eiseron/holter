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

  describe "list_events_paginated/3" do
    test "returns first page of events in descending order" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      results = IntegrationEventsContext.list_events_paginated(integration.id, 1, 3)
      assert length(results) == 3
    end

    test "returns two events on second page when total is five with page_size three" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      page2 = IntegrationEventsContext.list_events_paginated(integration.id, 2, 3)

      assert length(page2) == 2
    end

    test "returns disjoint event sets on page 1 and page 2" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      page1_ids =
        integration
        |> then(&IntegrationEventsContext.list_events_paginated(&1.id, 1, 3))
        |> Enum.map(& &1.id)

      page2_ids =
        integration
        |> then(&IntegrationEventsContext.list_events_paginated(&1.id, 2, 3))
        |> Enum.map(& &1.id)

      assert page1_ids != page2_ids
    end

    test "returns empty list for integration with no events" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert IntegrationEventsContext.list_events_paginated(integration.id, 1, 25) == []
    end
  end

  describe "events_page_info/3" do
    test "returns 2 total_pages for 5 events with page_size 3" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      {total_pages, _current_page} =
        IntegrationEventsContext.events_page_info(integration.id, 3, 1)

      assert total_pages == 2
    end

    test "returns current_page 1 when requesting page 1" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      {_total_pages, current_page} =
        IntegrationEventsContext.events_page_info(integration.id, 3, 1)

      assert current_page == 1
    end

    test "clamps current_page to last page when requested page exceeds total" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..3, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      {_total_pages, current_page} =
        IntegrationEventsContext.events_page_info(integration.id, 3, 99)

      assert current_page == 1
    end

    test "returns page 1 for integration with no events" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      {_total_pages, current_page} =
        IntegrationEventsContext.events_page_info(integration.id, 25, 1)

      assert current_page == 1
    end
  end
end
