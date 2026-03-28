defmodule Holter.Monitoring.Workers.HTTPCheck do
  use Oban.Worker, queue: :checks, max_attempts: 3

  alias Holter.Monitoring

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)
    start_time = System.monotonic_time()

    monitor
    |> build_req_options()
    |> Req.request()
    |> handle_request_result(monitor, start_time)
  end

  defp build_req_options(monitor) do
    [
      url: monitor.url,
      method: monitor.method |> to_string() |> String.downcase(),
      headers: monitor.headers,
      body: monitor.body,
      receive_timeout: (monitor.timeout_seconds || 30) * 1000
    ]
    |> maybe_ignore_ssl(monitor.ssl_ignore)
  end

  defp maybe_ignore_ssl(opts, true) do
    Keyword.put(opts, :connect_options, transport_opts: [verify: :verify_none])
  end

  defp maybe_ignore_ssl(opts, _), do: opts

  defp handle_request_result({:ok, response}, monitor, start_time) do
    process_response(monitor, response, duration_ms(start_time))
  end

  defp handle_request_result({:error, error}, monitor, start_time) do
    handle_failure(monitor, error, duration_ms(start_time))
  end

  defp duration_ms(start_time) do
    (System.monotonic_time() - start_time)
    |> System.convert_time_unit(:native, :millisecond)
  end

  defp process_response(monitor, response, duration) do
    status_ok = response.status >= 200 and response.status < 400
    body = to_string(response.body)

    keywords_ok =
      validate_positive(body, monitor.keyword_positive) and
        validate_negative(body, monitor.keyword_negative)

    final_status = if status_ok and keywords_ok, do: :up, else: :down

    error_msg = determine_error_message(status_ok, keywords_ok, response.status)

    finalize_check(monitor, final_status, response.status, duration, error_msg)
  end

  defp determine_error_message(false, _, status), do: "HTTP Error: #{status}"
  defp determine_error_message(_, false, _), do: "Keyword validation failed"
  defp determine_error_message(_, _, _), do: nil

  defp handle_failure(monitor, error, duration) do
    finalize_check(monitor, :down, nil, duration, Exception.message(error))
  end

  defp finalize_check(monitor, status, http_status, duration, error_msg) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    update_monitor_state(monitor, status, now)
    record_monitor_log(monitor.id, status, http_status, duration, error_msg, now)

    :ok
  end

  defp update_monitor_state(monitor, status, now) do
    Monitoring.update_monitor(monitor, %{
      health_status: status,
      last_checked_at: now,
      last_success_at: if(status == :up, do: now, else: monitor.last_success_at)
    })
  end

  defp record_monitor_log(monitor_id, status, http_status, duration, error_msg, now) do
    Monitoring.create_monitor_log(%{
      monitor_id: monitor_id,
      status: status,
      http_status: http_status,
      response_time_ms: duration,
      error_message: error_msg,
      checked_at: now
    })
  end

  defp validate_positive(_body, empty) when empty in [nil, []], do: true

  defp validate_positive(body, keywords) do
    Enum.all?(keywords, &String.contains?(body, &1))
  end

  defp validate_negative(_body, empty) when empty in [nil, []], do: true

  defp validate_negative(body, keywords) do
    not Enum.any?(keywords, &String.contains?(body, &1))
  end
end
