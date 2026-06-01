defmodule Holter.Integrations.Engine.ErrorHandler do
  @moduledoc false

  alias Holter.Integrations.Engine.ErrorClassifier
  alias Holter.Integrations.{IntegrationEventsContext, IntegrationsContext}

  @doc """
  Classifies the dispatch error, updates integration status when needed,
  logs an IntegrationEvent, and returns the appropriate Oban control tuple.
  """
  @spec handle(term(), term(), %{now: DateTime.t(), duration_ms: non_neg_integer()}) ::
          {:error, binary()} | {:discard, binary()} | {:snooze, non_neg_integer()}
  def handle(integration, error, %{now: now, duration_ms: duration_ms}) do
    error_class = ErrorClassifier.classify_error(integration.provider, error)

    update_attrs =
      ErrorClassifier.build_error_update_attrs(error_class, %{reason: error, now: now})

    retry_strategy = ErrorClassifier.determine_retry_strategy(error_class)

    apply_status_update(integration, update_attrs)

    log_error_event(integration, %{
      error_class: error_class,
      error: error,
      duration_ms: duration_ms,
      now: now
    })

    retry_strategy
  end

  defp apply_status_update(_integration, attrs) when map_size(attrs) == 0, do: :ok

  defp apply_status_update(integration, attrs) do
    IntegrationsContext.update_status(integration, attrs)
  end

  defp log_error_event(integration, %{
         error_class: error_class,
         error: error,
         duration_ms: duration_ms,
         now: now
       }) do
    IntegrationEventsContext.log_event!(%{
      integration_id: integration.id,
      direction: :outbound,
      action: "dispatch_error",
      target: "integration:#{integration.provider}",
      payload_redacted: %{error_class: error_class, reason: inspect(error)},
      status: :failed,
      duration_ms: duration_ms,
      occurred_at: DateTime.truncate(now, :second)
    })
  end
end
