defmodule Holter.Monitoring.Workers.HTTPCheck do
  use Oban.Worker, queue: :checks, max_attempts: 3

  alias Holter.Monitoring
  alias Holter.Monitoring.Engine

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id} = args}) do
    monitor = Monitoring.get_monitor!(id)
    start_time = System.monotonic_time()

    client = get_client(Map.get(args, "client_name"))

    monitor
    |> build_req_options()
    |> then(&apply(client, :request, [&1]))
    |> handle_request_result(monitor, start_time)
  end

  defp get_client("mock"), do: Holter.Monitoring.MonitorClientMock
  defp get_client("http"), do: Holter.Monitoring.MonitorClient.HTTP
  defp get_client(_), do: Application.get_env(:holter, :monitor_client)

  defp build_req_options(monitor) do
    [
      url: monitor.url,
      method: monitor.method |> to_string() |> String.downcase() |> String.to_existing_atom(),
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
    Engine.process_response(monitor, response, duration_ms(start_time))
  end

  defp handle_request_result({:error, error}, monitor, start_time) do
    Engine.handle_failure(monitor, error, duration_ms(start_time))
  end

  defp duration_ms(start_time) do
    (System.monotonic_time() - start_time)
    |> System.convert_time_unit(:native, :millisecond)
  end
end
