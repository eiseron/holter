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
    check_url(monitor, monitor.url, 0, start_time)
    :ok
  end

  defp check_url(monitor, url, redirects, start_time) do
    case validate_destination(url) do
      :ok ->
        fetch_response(monitor, url, redirects, start_time)

      {:error, reason} ->
        Engine.handle_failure(
          monitor,
          %RuntimeError{message: reason},
          calculate_duration(start_time)
        )
    end
  end

  defp fetch_response(monitor, url, redirects, start_time) do
    client = Application.get_env(:holter, :monitor_client, HTTP)
    opts = build_opts(monitor, url)

    case client.request(opts) do
      {:ok, response} -> handle_response(monitor, response, url, redirects, start_time)
      {:error, error} -> Engine.handle_failure(monitor, error, calculate_duration(start_time))
    end
  end

  defp handle_response(monitor, response, url, redirects, start_time) do
    should_follow =
      response.status in 301..308 and monitor.follow_redirects and
        redirects < monitor.max_redirects

    if should_follow do
      follow_redirect(monitor, response, url, redirects, start_time)
    else
      Engine.process_response(monitor, response, calculate_duration(start_time), redirects, url)
    end
  end

  defp follow_redirect(monitor, response, url, redirects, start_time) do
    case get_header(response.headers, "location") do
      nil ->
        Engine.process_response(monitor, response, calculate_duration(start_time), redirects, url)

      location ->
        location = if is_list(location), do: List.first(location), else: location
        next_url = URI.merge(url, location) |> to_string()
        check_url(monitor, next_url, redirects + 1, start_time)
    end
  end

  defp get_header(headers, key) do
    headers |> Enum.find_value(fn {k, v} -> if String.downcase(k) == key, do: v end)
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

  defp build_opts(monitor, url) do
    [
      method: normalize_method(monitor.method),
      url: url,
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
