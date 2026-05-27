defmodule Holter.Integrations.Engine.PayloadBuilder do
  @moduledoc false

  @doc """
  Builds the dispatch payload sent to a provider for a given event and incident.

  `targets` is the list of binding targets resolved by the Engine, e.g.
  `[%{"type" => "campaign", "id" => "gads-111", "label" => nil}, ...]`.

  Pure function — no side effects, no DB calls.
  """
  def build_dispatch_payload(integration, event, %{incident: incident, targets: targets})
      when is_list(targets) do
    %{
      integration_id: integration.id,
      provider: integration.provider,
      event: event,
      incident_id: incident.id,
      monitor_id: incident.monitor_id,
      workspace_id: integration.workspace_id,
      settings: integration.settings || %{},
      targets: targets
    }
  end

  @doc """
  Strips sensitive fields from a payload for storage in integration_events.

  Pure function — no side effects.
  """
  def build_redacted_payload(payload) do
    base = Map.take(payload, [:event, :incident_id, :monitor_id, :workspace_id])
    target_ids = Enum.map(payload[:targets] || [], &Map.get(&1, "id"))
    Map.put(base, :target_ids, target_ids)
  end
end
