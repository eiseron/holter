defmodule Holter.Integrations.Engine do
  @moduledoc false

  alias Holter.Integrations.{Broadcaster, IntegrationRulesContext, IntegrationsContext}
  alias Holter.Integrations.Workers.IntegrationDispatcher
  alias Holter.Repo.Tenant

  require Logger

  @doc """
  Called by EventConsumer when a monitoring incident PubSub message arrives.

  The incident broadcast carries `workspace_id` (stamped by Monitoring at
  publish time), which we use to enter the tenant context before any read.
  Without it the reads below would hit FORCE-RLS tables with no GUC and
  return nothing in production.

  Looks up rules for the incident's monitor + event, groups them by
  integration, and enqueues one IntegrationDispatcher job per integration
  carrying the list of targets from the rules.

  An integration without any rule for the (monitor, event) pair is
  intentionally not triggered — rules are the explicit opt-in.
  """
  def dispatch_event(%{workspace_id: workspace_id} = incident, event)
      when is_binary(event) and is_binary(workspace_id) do
    Tenant.with_workspace!(workspace_id, fn ->
      do_dispatch_event(incident, workspace_id, event)
    end)
  end

  def dispatch_event(incident, event) when is_binary(event) do
    Logger.warning(
      "integrations: incident #{inspect(Map.get(incident, :id))} missing workspace_id; skipping dispatch"
    )

    :ok
  end

  defp do_dispatch_event(incident, workspace_id, event) do
    grouped =
      incident.monitor_id
      |> IntegrationRulesContext.list_active_for_monitor_event(event)
      |> IntegrationRulesContext.group_by_integration()

    integrations_by_id =
      grouped
      |> Map.keys()
      |> IntegrationsContext.list_by_ids(workspace_id)
      |> Map.new(&{&1.id, &1})

    Enum.each(grouped, fn {integration_id, rules} ->
      case Map.fetch(integrations_by_id, integration_id) do
        {:ok, %{status: :active} = integration} ->
          enqueue_dispatch(%{
            integration: integration,
            workspace_id: workspace_id,
            event: event,
            incident: incident,
            rules: rules
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
         rules: rules
       }) do
    args = %{
      "integration_id" => integration.id,
      "workspace_id" => workspace_id,
      "event" => event,
      "incident_id" => incident.id,
      "monitor_id" => incident.monitor_id,
      "targets" => Enum.map(rules, &serialize_target/1)
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

  defp serialize_target(rule) do
    %{
      "type" => rule.target_type,
      "action" => rule.action,
      "id" => rule.target_id,
      "label" => rule.target_label
    }
  end
end
