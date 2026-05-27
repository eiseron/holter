defmodule Holter.Integrations.Engine do
  @moduledoc false

  alias Holter.Integrations.{Broadcaster, IntegrationBindingsContext, IntegrationsContext}
  alias Holter.Integrations.Workers.IntegrationDispatcher
  alias Holter.Monitoring

  require Logger

  @doc """
  Called by EventConsumer when a monitoring incident PubSub message arrives.

  Looks up bindings for the incident's monitor + event, groups them by
  integration, and enqueues one IntegrationDispatcher job per integration
  carrying the list of targets from the bindings.

  An integration without any binding for the (monitor, event) pair is
  intentionally not triggered — bindings are the explicit opt-in.
  """
  def dispatch_event(incident, event) when is_binary(event) do
    monitor = Monitoring.get_monitor!(incident.monitor_id)
    workspace_id = monitor.workspace_id

    grouped =
      incident.monitor_id
      |> IntegrationBindingsContext.list_active_for_monitor_event(event)
      |> IntegrationBindingsContext.group_by_integration()

    integrations_by_id =
      grouped
      |> Map.keys()
      |> IntegrationsContext.list_by_ids()
      |> Map.new(&{&1.id, &1})

    Enum.each(grouped, fn {integration_id, bindings} ->
      case Map.fetch(integrations_by_id, integration_id) do
        {:ok, %{status: :active} = integration} ->
          enqueue_dispatch(%{
            integration: integration,
            workspace_id: workspace_id,
            event: event,
            incident: incident,
            bindings: bindings
          })

        _ ->
          :ok
      end
    end)

    Broadcaster.broadcast_dispatch_attempted(workspace_id, event)
  end

  defp enqueue_dispatch(%{
         integration: integration,
         workspace_id: workspace_id,
         event: event,
         incident: incident,
         bindings: bindings
       }) do
    args = %{
      "integration_id" => integration.id,
      "workspace_id" => workspace_id,
      "event" => event,
      "incident_id" => incident.id,
      "monitor_id" => incident.monitor_id,
      "targets" => Enum.map(bindings, &serialize_target/1)
    }

    case Oban.insert(IntegrationDispatcher.new(args)) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "integrations: failed to enqueue dispatch for #{integration.id}: #{inspect(reason)}"
        )
    end
  end

  defp serialize_target(binding) do
    %{
      "type" => binding.target_type,
      "action" => binding.action,
      "id" => binding.target_id,
      "label" => binding.target_label
    }
  end
end
