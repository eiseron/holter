defmodule Holter.Integrations.Broadcaster do
  @moduledoc false

  def broadcast_dispatch_attempted(workspace_id, event) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "integrations:events",
      {:integration_dispatch_attempted, %{workspace_id: workspace_id, event: event}}
    )
  end

  def broadcast_integration_status_changed(integration_id, status) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "integrations:events",
      {:integration_status_changed, %{integration_id: integration_id, status: status}}
    )
  end

  def broadcast_integration_dispatched(integration_id, event, result) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "integrations:events",
      {:integration_dispatched, %{integration_id: integration_id, event: event, result: result}}
    )
  end
end
