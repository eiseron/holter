defmodule Holter.Monitoring.Workers.HTTPCheck do
  @moduledoc """
  Oban worker for performing HTTP availability checks.
  """
  use Oban.Worker, queue: :checks, max_attempts: 3

  alias Holter.Monitoring
  alias Holter.Monitoring.Engine
  alias Holter.Monitoring.MonitorClient.HTTP
  alias Holter.Monitoring.MonitorClientMock

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id} = args}) do
    monitor = Monitoring.get_monitor!(id)
    start_time = System.monotonic_time()
    client = fetch_client(args["client_name"])

    monitor
    |> build_request_options()
    |> perform_request(client)
    |> process_result(monitor, start_time)

    :ok
  end

  defp fetch_client("mock"), do: MonitorClientMock
  defp fetch_client("http"), do: HTTP
  defp fetch_client(_), do: Application.get_env(:holter, :monitor_client, HTTP)

  defp perform_request(opts, client), do: client.request(opts)

  defp process_result({:ok, response}, monitor, start_time) do
    Engine.process_response(monitor, response, calculate_duration(start_time))
  end

  defp process_result({:error, error}, monitor, start_time) do
    Engine.handle_failure(monitor, error, calculate_duration(start_time))
  end

  defp build_request_options(monitor) do
    [
      url: monitor.url,
      method: normalize_method(monitor.method),
      headers: monitor.headers,
      body: monitor.body,
      receive_timeout: (monitor.timeout_seconds || 30) * 1000
    ]
    |> apply_ssl_options(monitor.ssl_ignore)
  end

  defp normalize_method(method) do
    method |> to_string() |> String.downcase() |> String.to_existing_atom()
  end

  defp apply_ssl_options(opts, true) do
    Keyword.put(opts, :connect_options, transport_opts: [verify: :verify_none])
  end

  defp apply_ssl_options(opts, _), do: opts

  defp calculate_duration(start_time) do
    (System.monotonic_time() - start_time)
    |> System.convert_time_unit(:native, :millisecond)
  end
end
