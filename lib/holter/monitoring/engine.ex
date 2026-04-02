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

    body =
      case response.body do
        body when is_binary(body) -> body
        body when is_map(body) -> Jason.encode!(body)
        _ -> ""
      end

    positive_ok = validate_positive(body, monitor.keyword_positive)
    negative_ok = validate_negative(body, monitor.keyword_negative)

    check_status =
      cond do
        not status_ok or not positive_ok -> :down
        not negative_ok -> :compromised
        true -> :up
      end

    log_status = if check_status == :up, do: :success, else: :failure
    snippet = if check_status != monitor.health_status, do: String.slice(body, 0, 512), else: nil
    error_msg = determine_error_message(status_ok, positive_ok, negative_ok, response.status)

    finalize_check(
      monitor,
      check_status,
      log_status,
      response.status,
      duration_ms,
      error_msg,
      snippet
    )
  end

  @doc """
  Processes a network/request failure.
  """
  def handle_failure(monitor, error, duration_ms) do
    finalize_check(monitor, :down, :failure, nil, duration_ms, Exception.message(error), nil)
  end

  defp determine_error_message(false, _, _, status), do: "HTTP Error: #{status}"
  defp determine_error_message(true, false, _, _), do: "Missing required keywords"
  defp determine_error_message(true, true, false, _), do: "Found forbidden keywords"
  defp determine_error_message(_, _, _, _), do: nil

  defp finalize_check(
         monitor,
         check_status,
         log_status,
         status_code,
         duration_ms,
         error_msg,
         snippet
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    handle_incident_logic(monitor, check_status, error_msg, now)
    updated_monitor = update_monitor_state(monitor, check_status, now)

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

    {:ok, updated_monitor}
  end

  defp handle_incident_logic(monitor, :up, _error_msg, now) do
    resolve_if_open(monitor, :downtime, now)
    resolve_if_open(monitor, :defacement, now)
  end

  defp handle_incident_logic(monitor, :down, error_msg, now) do
    open_if_missing(monitor, :downtime, error_msg, now)
  end

  defp handle_incident_logic(monitor, :compromised, error_msg, now) do
    resolve_if_open(monitor, :downtime, now)
    open_if_missing(monitor, :defacement, error_msg, now)
  end

  defp resolve_if_open(monitor, type, now) do
    case Monitoring.get_open_incident(monitor.id, type) do
      nil -> :ok
      incident -> Monitoring.resolve_incident(incident, now)
    end
  end

  defp open_if_missing(monitor, type, error_msg, now) do
    case Monitoring.get_open_incident(monitor.id, type) do
      nil ->
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: type,
          started_at: now,
          root_cause: error_msg
        })

      _ ->
        :ok
    end
  end

  defp update_monitor_state(monitor, check_status, now) do
    {:ok, updated_monitor} =
      Monitoring.update_monitor(monitor, %{
        last_checked_at: now,
        last_success_at: if(check_status == :up, do: now, else: monitor.last_success_at)
      })

    {:ok, fully_updated} = Monitoring.recalculate_health_status(updated_monitor)
    fully_updated
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
