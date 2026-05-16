defmodule Holter.Integrations.Engine do
  @moduledoc false

  alias Holter.Integrations.{Broadcaster, IntegrationsContext}
  alias Holter.Integrations.Workers.IntegrationDispatcher
  alias Holter.Monitoring

  require Logger

  @doc """
  Called by EventConsumer when a monitoring incident PubSub message arrives.

  Looks up the workspace from the incident's monitor, fetches active integrations
  subscribed to the event, and enqueues one IntegrationDispatcher job per integration.
  """
  def dispatch_event(incident, event) when is_binary(event) do
    monitor = Monitoring.get_monitor!(incident.monitor_id)
    workspace_id = monitor.workspace_id

    workspace_id
    |> IntegrationsContext.list_active_for_event(event)
    |> Enum.each(fn integration ->
      args = %{
        "integration_id" => integration.id,
        "workspace_id" => workspace_id,
        "event" => event,
        "incident_id" => incident.id,
        "monitor_id" => incident.monitor_id
      }

      case Oban.insert(IntegrationDispatcher.new(args)) do
        {:ok, _job} ->
          :ok

        {:error, reason} ->
          Logger.error(
            "integrations: failed to enqueue dispatch for #{integration.id}: #{inspect(reason)}"
          )
      end
    end)

    Broadcaster.broadcast_dispatch_attempted(workspace_id, event)
  end
end
