defmodule Holter.Monitoring.Engine do
  @moduledoc """
  Core monitoring logic detached from Oban workers.
  This service handles response processing, keyword validation, 
  incident lifecycle, and monitor log creation.
  """
  alias Holter.Monitoring

  @doc """
  Processes a successful HTTP response against a monitor.
  """
  def process_response(monitor, response, duration_ms) do
    status_ok = response.status >= 200 and response.status < 400
    
    body = case response.body do
      body when is_binary(body) -> body
      body when is_map(body) -> Jason.encode!(body)
      _ -> ""
    end

    keywords_ok =
      validate_positive(body, monitor.keyword_positive) and
        validate_negative(body, monitor.keyword_negative)

    final_status = if status_ok and keywords_ok, do: :up, else: :down
    log_status = if final_status == :up, do: :success, else: :failure
    snippet = if final_status != monitor.health_status, do: String.slice(body, 0, 512), else: nil
    error_msg = determine_error_message(status_ok, keywords_ok, response.status)

    finalize_check(monitor, final_status, log_status, response.status, duration_ms, error_msg, snippet)
  end

  @doc """
  Processes a network/request failure.
  """
  def handle_failure(monitor, error, duration_ms) do
    finalize_check(monitor, :down, :failure, nil, duration_ms, Exception.message(error), nil)
  end

  defp determine_error_message(false, _, status), do: "HTTP Error: #{status}"
  defp determine_error_message(_, false, _), do: "Keyword validation failed"
  defp determine_error_message(_, _, _), do: nil

  defp finalize_check(monitor, status, log_status, status_code, duration_ms, error_msg, snippet) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    handle_incident_logic(monitor, status, error_msg, now)
    update_monitor_state(monitor, status, now)
    
    record_monitor_log(%{
      monitor_id: monitor.id,
      status: log_status,
      status_code: status_code,
      latency_ms: duration_ms,
      error_message: error_msg,
      response_snippet: snippet,
      region: get_region(),
      checked_at: now
    })

    :ok
  end

  defp handle_incident_logic(monitor, :down, error_msg, now) do
    if monitor.health_status == :up or is_nil(monitor.health_status) do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :downtime,
        started_at: now,
        root_cause: error_msg
      })
    end
  end

  defp handle_incident_logic(monitor, :up, _error_msg, now) do
    if monitor.health_status == :down do
      case Monitoring.get_open_incident(monitor.id) do
        nil -> :ok
        incident -> Monitoring.resolve_incident(incident, now)
      end
    end
  end

  defp update_monitor_state(monitor, status, now) do
    Monitoring.update_monitor(monitor, %{
      health_status: status,
      last_checked_at: now,
      last_success_at: if(status == :up, do: now, else: monitor.last_success_at)
    })
  end

  defp record_monitor_log(attrs) do
    Monitoring.create_monitor_log(attrs)
  end

  defp get_region do
    System.get_env("MONITOR_REGION", "br-sp-1")
  end

  defp validate_positive(_body, empty) when empty in [nil, []], do: true
  defp validate_positive(body, keywords), do: Enum.all?(keywords, &String.contains?(body, &1))

  defp validate_negative(_body, empty) when empty in [nil, []], do: true
  defp validate_negative(body, keywords), do: not Enum.any?(keywords, &String.contains?(body, &1))
end
