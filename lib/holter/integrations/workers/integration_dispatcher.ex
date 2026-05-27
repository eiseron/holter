defmodule Holter.Integrations.Workers.IntegrationDispatcher do
  @moduledoc false

  use Holter.Monitoring.Workers.WorkspaceScopedWorker,
    queue: :integrations,
    max_attempts: 5

  alias Holter.Integrations.{Broadcaster, IntegrationEventsContext, IntegrationsContext, Provider}
  alias Holter.Integrations.Engine.PayloadBuilder

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "integration_id" => integration_id,
            "event" => event,
            "incident_id" => incident_id
          } = args
      }) do
    integration = IntegrationsContext.get!(integration_id)

    case Provider.provider_module(integration.provider) do
      {:error, :not_implemented} ->
        {:discard, "no module for provider #{integration.provider}"}

      {:ok, provider_mod} ->
        monitor_id = args["monitor_id"]
        targets = args["targets"] || []
        incident_stub = %{id: incident_id, monitor_id: monitor_id}

        payload =
          PayloadBuilder.build_dispatch_payload(integration, event, %{
            incident: incident_stub,
            targets: targets
          })

        run_dispatch(provider_mod, %{integration: integration, event: event, payload: payload})
    end
  end

  defp run_dispatch(provider_mod, %{integration: integration, event: event, payload: payload}) do
    started_at = System.monotonic_time(:millisecond)
    result = provider_mod.dispatch(integration, event, payload)
    duration_ms = System.monotonic_time(:millisecond) - started_at

    log_dispatch_event(
      %{integration: integration, event: event, payload: payload},
      result,
      duration_ms
    )

    Broadcaster.broadcast_integration_dispatched(integration.id, event, result)

    case result do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp log_dispatch_event(
         %{integration: integration, event: event, payload: payload},
         result,
         duration_ms
       ) do
    {status, extra} =
      case result do
        :ok -> {:success, %{}}
        {:error, reason} -> {:failed, %{error: inspect(reason)}}
      end

    IntegrationEventsContext.log_event!(%{
      integration_id: integration.id,
      direction: :outbound,
      action: event,
      target: "integration:#{integration.provider}",
      payload_redacted: Map.merge(PayloadBuilder.build_redacted_payload(payload), extra),
      status: status,
      duration_ms: duration_ms,
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end
end
