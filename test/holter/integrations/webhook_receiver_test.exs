defmodule Holter.Integrations.WebhookReceiverTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.IntegrationEventsContext
  alias Holter.Integrations.WebhookReceiver

  defp request(provider, verified?, params \\ %{}) do
    %{provider: provider, params: params, verified?: verified?}
  end

  describe "process_inbound/2" do
    test "returns {:ok, :processed} for a verified request when workspace and integration exist" do
      ws = workspace_fixture()
      _integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      assert {:ok, :processed} =
               WebhookReceiver.process_inbound(ws.slug, request(:google_ads, true))
    end

    test "returns {:ok, :ignored} for an unverified request" do
      ws = workspace_fixture()
      _integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      assert {:ok, :ignored} =
               WebhookReceiver.process_inbound(ws.slug, request(:google_ads, false))
    end

    test "returns {:error, :not_found} when workspace does not exist" do
      assert {:error, :not_found} =
               WebhookReceiver.process_inbound(
                 "nonexistent-workspace",
                 request(:google_ads, true)
               )
    end

    test "returns {:error, :not_found} when integration does not exist for the provider" do
      ws = workspace_fixture()

      assert {:error, :not_found} =
               WebhookReceiver.process_inbound(ws.slug, request(:slack, true))
    end

    test "logs an inbound integration event on a verified request" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      {:ok, :processed} = WebhookReceiver.process_inbound(ws.slug, request(:google_ads, true))

      events = IntegrationEventsContext.list_events(integration.id, direction: :inbound)

      assert length(events) == 1
    end

    test "does not log any event for an unverified request (no storage amplification)" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      {:ok, :ignored} = WebhookReceiver.process_inbound(ws.slug, request(:google_ads, false))

      events = IntegrationEventsContext.list_events(integration.id, direction: :inbound)

      assert events == []
    end

    test "logged event has action webhook_received" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      {:ok, :processed} = WebhookReceiver.process_inbound(ws.slug, request(:google_ads, true))

      [event] = IntegrationEventsContext.list_events(integration.id, direction: :inbound)

      assert event.action == "webhook_received"
    end
  end
end
