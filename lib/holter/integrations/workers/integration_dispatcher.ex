defmodule Holter.Integrations.Workers.IntegrationDispatcher do
  @moduledoc false

  use Holter.Monitoring.Workers.WorkspaceScopedWorker,
    queue: :integrations,
    max_attempts: 5

  alias Holter.Integrations.{
    Broadcaster,
    IntegrationEventsContext,
    IntegrationsContext,
    OAuth,
    Provider
  }

  alias Holter.Integrations.Engine.{ActionRunner, ErrorHandler, PayloadBuilder}
  alias Holter.Integrations.RateLimiter

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "integration_id" => integration_id,
            "event" => _event,
            "incident_id" => _incident_id
          } = args
      }) do
    integration = IntegrationsContext.get!(integration_id)

    case Provider.provider_module(integration.provider) do
      {:error, :not_implemented} ->
        {:discard, "no module for provider #{integration.provider}"}

      {:ok, provider_mod} ->
        dispatch_with_refresh(provider_mod, integration, args)
    end
  end

  defp dispatch_with_refresh(provider_mod, integration, args) do
    now = DateTime.utc_now()

    with :ok <- RateLimiter.check_rate(integration.id, integration.provider),
         {:ok, refreshed} <- OAuth.refresh_if_needed(integration, now) do
      build_and_dispatch(provider_mod, %{integration: refreshed, args: args, now: now})
    else
      {:error, :rate_limited} ->
        {:snooze, 60}

      {:error, :reauth_required} ->
        {:discard, "integration #{integration.id} requires reauth"}

      {:error, reason} ->
        ErrorHandler.handle(integration, reason, %{now: now, duration_ms: 0})
    end
  end

  defp build_and_dispatch(provider_mod, %{integration: integration, args: args, now: now}) do
    event = args["event"]

    payload =
      PayloadBuilder.build_dispatch_payload(integration, event, %{
        incident: %{id: args["incident_id"], monitor_id: args["monitor_id"]},
        targets: args["targets"] || []
      })

    run_dispatch(provider_mod, %{integration: integration, event: event, payload: payload}, now)
  end

  defp run_dispatch(
         provider_mod,
         %{integration: integration, event: event, payload: payload},
         now
       ) do
    started_at = System.monotonic_time(:millisecond)
    result = ActionRunner.run(provider_mod, integration, payload)
    duration_ms = System.monotonic_time(:millisecond) - started_at

    case result do
      :ok ->
        log_success_event(
          %{integration: integration, event: event, payload: payload},
          duration_ms,
          now
        )

        Broadcaster.broadcast_integration_dispatched(integration.id, event, :ok)
        :ok

      {:error, reason} ->
        Broadcaster.broadcast_integration_dispatched(integration.id, event, {:error, reason})
        ErrorHandler.handle(integration, reason, %{now: now, duration_ms: duration_ms})
    end
  end

  defp log_success_event(
         %{integration: integration, event: event, payload: payload},
         duration_ms,
         now
       ) do
    IntegrationEventsContext.log_event!(%{
      integration_id: integration.id,
      direction: :outbound,
      action: event,
      target: "integration:#{integration.provider}",
      payload_redacted: PayloadBuilder.build_redacted_payload(payload),
      status: :success,
      duration_ms: duration_ms,
      occurred_at: DateTime.truncate(now, :second)
    })
  end
end
