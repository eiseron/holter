defmodule Holter.Monitoring.Workers.HTTPCheck do
  use Oban.Worker, queue: :checks, max_attempts: 3

  alias Holter.Monitoring

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)
    start_time = System.monotonic_time()

    # Prepare Request options
    req_options = [
      url: monitor.url,
      method: monitor.method,
      headers: monitor.headers,
      body: monitor.body,
      receive_timeout: (monitor.timeout_seconds || 30) * 1000,
      connect_timeout: 10_000
    ]

    # Handle SSL ignore
    req_options =
      if monitor.ssl_ignore do
        Keyword.put(req_options, :connect_options, transport_opts: [verify: :verify_none])
      else
        req_options
      end

    case Req.request(req_options) do
      {:ok, response} ->
        duration = duration_ms(start_time)
        process_response(monitor, response, duration)

      {:error, error} ->
        duration = duration_ms(start_time)
        handle_failure(monitor, error, duration)
    end
  end

  defp duration_ms(start_time) do
    (System.monotonic_time() - start_time)
    |> System.convert_time_unit(:native, :millisecond)
  end

  defp process_response(monitor, response, duration) do
    # 1. Check HTTP Status (Must be 2xx or 3xx)
    status_ok = response.status >= 200 and response.status < 400

    # 2. Check Keywords
    body = to_string(response.body)

    keywords_ok =
      validate_positive(body, monitor.keyword_positive) and
        validate_negative(body, monitor.keyword_negative)

    final_status = if status_ok and keywords_ok, do: :up, else: :down

    error_msg =
      cond do
        not status_ok -> "HTTP Error: #{response.status}"
        not keywords_ok -> "Keyword validation failed"
        true -> nil
      end

    finalize_check(monitor, final_status, response.status, duration, error_msg)
  end

  defp handle_failure(monitor, error, duration) do
    error_msg = Exception.message(error)
    finalize_check(monitor, :down, nil, duration, error_msg)
  end

  defp finalize_check(monitor, status, http_status, duration, error_msg) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Update Monitor State
    Monitoring.update_monitor(monitor, %{
      health_status: status,
      last_checked_at: now,
      last_success_at: if(status == :up, do: now, else: monitor.last_success_at)
    })

    # Record Log
    Monitoring.create_monitor_log(%{
      monitor_id: monitor.id,
      status: status,
      http_status: http_status,
      response_time_ms: duration,
      error_message: error_msg,
      checked_at: now
    })

    :ok
  end

  defp validate_positive(_body, nil), do: true
  defp validate_positive(_body, []), do: true

  defp validate_positive(body, keywords) do
    Enum.all?(keywords, fn kw -> String.contains?(body, kw) end)
  end

  defp validate_negative(_body, nil), do: true
  defp validate_negative(_body, []), do: true

  defp validate_negative(body, keywords) do
    not Enum.any?(keywords, fn kw -> String.contains?(body, kw) end)
  end
end
