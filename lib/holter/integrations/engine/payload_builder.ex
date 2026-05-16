defmodule Holter.Integrations.Engine.PayloadBuilder do
  @moduledoc false

  @doc """
  Builds the dispatch payload sent to a provider for a given event and incident.

  Pure function — no side effects, no DB calls.
  """
  def build_dispatch_payload(integration, event, incident) do
    %{
      integration_id: integration.id,
      provider: integration.provider,
      event: event,
      incident_id: incident.id,
      monitor_id: incident.monitor_id,
      workspace_id: integration.workspace_id,
      settings: integration.settings || %{},
      subscribed_events: integration.subscribed_events || []
    }
  end

  @doc """
  Strips sensitive fields from a payload for storage in integration_events.

  Pure function — no side effects.
  """
  def build_redacted_payload(payload) do
    base = Map.take(payload, [:event, :incident_id, :monitor_id, :workspace_id])
    settings_ids = Map.take(payload[:settings] || %{}, ["campaign_ids", "ad_set_ids"])
    Map.merge(base, settings_ids)
  end
end
