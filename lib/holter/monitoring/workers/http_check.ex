defmodule Holter.Monitoring.Workers.HTTPCheck do
  @moduledoc """
  Oban worker for performing HTTP availability checks.
  """
  use Oban.Worker,
    queue: :checks,
    max_attempts: 3,
    unique: [period: 60, states: [:available, :scheduled, :executing]]

  alias Holter.Monitoring
  alias Holter.Monitoring.Engine
  alias Holter.Monitoring.MonitorClient.HTTP

  @max_timeout_seconds 30

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)

    state = %{
      url: monitor.url,
      safe_ip: nil,
      redirects: 0,
      redirect_list: [],
      start_time: nil
    }

    fetch_hop(monitor, state)
    :ok
  end

  defp fetch_hop(monitor, %{url: url} = state) do
    case validate_destination(url) do
      {:ok, safe_ip} ->
        hop = %{"url" => url, "ip" => safe_ip}

        fetch_response(monitor, %{
          state
          | safe_ip: safe_ip,
            start_time: state.start_time || System.monotonic_time(),
            redirect_list: state.redirect_list ++ [hop]
        })

      {:error, reason} ->
        start_time = state.start_time || System.monotonic_time()

        Engine.handle_failure(
          monitor,
          %RuntimeError{message: reason},
          calculate_duration(start_time)
        )
    end
  end

  defp fetch_response(monitor, state) do
    remaining_timeout = calculate_remaining_timeout(monitor, state.start_time)

    if remaining_timeout <= 0 do
      Engine.handle_failure(
        monitor,
        %RuntimeError{message: "Global timeout exceeded"},
        calculate_duration(state.start_time)
      )
    else
      execute_request(monitor, state, remaining_timeout)
    end
  end

  defp calculate_remaining_timeout(monitor, start_time) do
    elapsed_ms = calculate_duration(start_time)
    capped = min(monitor.timeout_seconds, @max_timeout_seconds)
    capped * 1000 - elapsed_ms
  end

  defp execute_request(monitor, state, remaining_timeout) do
    client = Application.get_env(:holter, :monitor_client, HTTP)

    opts =
      build_opts(monitor, %{url: state.url, safe_ip: state.safe_ip, timeout: remaining_timeout})

    case client.request(opts) do
      {:ok, response} ->
        handle_response(monitor, response, %{
          state: state,
          duration: calculate_duration(state.start_time)
        })

      {:error, error} ->
        Engine.handle_failure(monitor, error, calculate_duration(state.start_time))
    end
  end

  defp handle_response(monitor, response, params) do
    state = params.state
    current_duration = params.duration

    state = %{
      state
      | redirect_list:
          List.update_at(state.redirect_list, -1, &Map.put(&1, "status_code", response.status))
    }

    should_follow =
      response.status in 301..308 and monitor.follow_redirects and
        state.redirects < monitor.max_redirects

    if should_follow do
      follow_redirect(monitor, response, state)
    else
      Engine.process_response(monitor, response, %{
        duration_ms: current_duration,
        redirects: state.redirects,
        last_url: state.url,
        redirect_list: state.redirect_list
      })
    end
  end

  defp follow_redirect(monitor, response, state) do
    case get_header(response.headers, "location") do
      nil ->
        Engine.process_response(monitor, response, %{
          duration_ms: calculate_duration(state.start_time),
          redirects: state.redirects,
          last_url: state.url,
          redirect_list: state.redirect_list
        })

      location ->
        location = if is_list(location), do: List.first(location), else: location
        next_url = URI.merge(state.url, location) |> to_string()
        fetch_hop(monitor, %{state | url: next_url, redirects: state.redirects + 1})
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
          {:ok, List.first(ips)}
        end

      {:error, _} ->
        {:ok, host}
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

  defp build_opts(monitor, params) do
    url = params.url
    safe_ip = params.safe_ip
    remaining_timeout = params.timeout
    uri = URI.parse(url)
    original_host = uri.host

    safe_url =
      if original_host != safe_ip do
        ip_host = if String.contains?(safe_ip, ":"), do: "[#{safe_ip}]", else: safe_ip
        URI.to_string(%{uri | host: ip_host})
      else
        url
      end

    headers = Map.put(monitor.headers, "host", original_host)

    [
      method: normalize_method(monitor.method),
      url: safe_url,
      headers: headers,
      body: monitor.body,
      receive_timeout: remaining_timeout,
      redirect: false
    ]
    |> apply_ssl_options(monitor.ssl_ignore, original_host)
  end

  defp normalize_method(method) do
    method |> to_string() |> String.downcase() |> String.to_existing_atom()
  end

  defp apply_ssl_options(opts, ignore_ssl, original_host) do
    transport_opts = [server_name_indication: to_charlist(original_host)]

    transport_opts =
      if ignore_ssl do
        Keyword.put(transport_opts, :verify, :verify_none)
      else
        transport_opts
      end

    Keyword.put(opts, :connect_options, transport_opts: transport_opts)
  end

  defp calculate_duration(start_time) do
    (System.monotonic_time() - start_time)
    |> System.convert_time_unit(:native, :millisecond)
  end
end
