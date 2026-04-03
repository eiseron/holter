defmodule Holter.Monitoring.Workers.HTTPCheck do
  @moduledoc """
  Oban worker for performing HTTP availability checks.
  """
  use Oban.Worker, queue: :checks, max_attempts: 3

  alias Holter.Monitoring
  alias Holter.Monitoring.Engine
  alias Holter.Monitoring.MonitorClient.HTTP

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)
    start_time = System.monotonic_time()
    client = Application.get_env(:holter, :monitor_client, HTTP)

    case validate_destination(monitor.url) do
      :ok ->
        monitor
        |> build_request_options()
        |> perform_request(client)
        |> process_result(monitor, start_time)

      {:error, reason} ->
        Engine.handle_failure(
          monitor,
          %RuntimeError{message: reason},
          calculate_duration(start_time)
        )
    end

    :ok
  end

  defp perform_request(opts, client), do: client.request(opts)

  defp process_result({:ok, response}, monitor, start_time) do
    Engine.process_response(monitor, response, calculate_duration(start_time))
  end

  defp process_result({:error, error}, monitor, start_time) do
    Engine.handle_failure(monitor, error, calculate_duration(start_time))
  end

  defp validate_destination(url) do
    host = URI.parse(url).host

    case resolve_host(host) do
      {:ok, ips} ->
        if Enum.any?(ips, &restricted_ip?(&1)) do
          {:error, "Access to restricted internal address blocked (DNS Validation)"}
        else
          :ok
        end

      {:error, _} ->
        :ok
    end
  end

  def resolve_host(nil), do: {:error, :no_host}

  def resolve_host(host) do
    case :inet.getaddrs(to_charlist(host), :inet) do
      {:ok, addrs} -> {:ok, Enum.map(addrs, fn addr -> :inet.ntoa(addr) |> to_string() end)}
      error -> error
    end
  end

  defp restricted_ip?(ip) do
    trusted = get_trusted_hosts()

    case :inet.parse_address(to_charlist(ip)) do
      {:ok, addr} -> private_network_address?(addr) and ip not in trusted
      _ -> false
    end
  end

  defp get_trusted_hosts do
    :holter
    |> Application.get_env(:monitoring, [])
    |> Keyword.get(:trusted_hosts, [])
  end

  defp private_network_address?({127, _, _, _}), do: true
  defp private_network_address?({10, _, _, _}), do: true
  defp private_network_address?({172, s, _, _}) when s >= 16 and s <= 31, do: true
  defp private_network_address?({192, 168, _, _}), do: true
  defp private_network_address?({169, 254, _, _}), do: true
  defp private_network_address?({0, 0, 0, 0}), do: true
  defp private_network_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp private_network_address?(_), do: false

  defp build_request_options(monitor) do
    [
      method: normalize_method(monitor.method),
      url: monitor.url,
      headers: monitor.headers,
      body: monitor.body,
      receive_timeout: monitor.timeout_seconds * 1000,
      redirect: false
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
