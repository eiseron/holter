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
  alias Holter.Network.Guard

  @max_timeout_seconds 30

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)

    state = %{
      url: monitor.url,
      safe_ip: nil,
      redirects: 0,
      redirect_list: [],
      start_time: nil,
      last_hop_duration_ms: nil
    }

    run_hops(monitor, state)
    :ok
  end

  defp run_hops(monitor, state) do
    case do_one_hop(monitor, state) do
      {:redirect, new_state} ->
        run_hops(monitor, new_state)

      {:done, {response, meta}} ->
        Engine.process_response(monitor, response, meta)

      {:failure, {error, duration_ms}} ->
        Engine.handle_failure(monitor, error, duration_ms)
    end
  end

  defp do_one_hop(monitor, state) do
    start_time = state.start_time || System.monotonic_time()
    state = %{state | start_time: start_time}

    case Guard.validate_destination(state.url) do
      {:error, :unresolved} ->
        {:failure,
         {%RuntimeError{message: "DNS resolution failed"}, calculate_duration(start_time)}}

      {:error, _reason} ->
        {:failure,
         {%RuntimeError{
            message: "Access to restricted internal address blocked (DNS Validation)"
          }, calculate_duration(start_time)}}

      {:ok, safe_ip} ->
        hop = %{"url" => state.url, "ip" => safe_ip}
        state = %{state | safe_ip: safe_ip, redirect_list: state.redirect_list ++ [hop]}
        remaining_timeout = calculate_remaining_timeout(monitor, start_time)

        if remaining_timeout <= 0 do
          {:failure,
           {%RuntimeError{message: "Global timeout exceeded"}, calculate_duration(start_time)}}
        else
          do_request(monitor, state, remaining_timeout)
        end
    end
  end

  defp do_request(monitor, state, remaining_timeout) do
    client = Application.get_env(:holter, :monitor_client, HTTP)

    opts =
      build_opts(monitor, %{url: state.url, safe_ip: state.safe_ip, timeout: remaining_timeout})

    hop_start = System.monotonic_time()

    case client.request(opts) do
      {:ok, response} ->
        hop_ms = calculate_duration(hop_start)

        state = %{
          state
          | last_hop_duration_ms: hop_ms,
            redirect_list:
              List.update_at(
                state.redirect_list,
                -1,
                &Map.merge(&1, %{"status_code" => response.status, "latency_ms" => hop_ms})
              )
        }

        decide_after_response(monitor, state, response)

      {:error, error} ->
        {:failure, {error, calculate_duration(hop_start)}}
    end
  end

  defp decide_after_response(monitor, state, response) do
    should_follow =
      response.status in 301..308 and monitor.follow_redirects and
        state.redirects < monitor.max_redirects

    if should_follow do
      case get_header(response.headers, "location") do
        nil ->
          {:done, {response, build_meta(state)}}

        location ->
          next_url = URI.merge(state.url, normalize_location(location)) |> to_string()
          {:redirect, %{state | url: next_url, redirects: state.redirects + 1}}
      end
    else
      {:done, {response, build_meta(state)}}
    end
  end

  defp build_meta(state) do
    %{
      duration_ms: state.last_hop_duration_ms,
      redirects: state.redirects,
      last_url: state.url,
      redirect_list: state.redirect_list
    }
  end

  defp normalize_location(l) when is_list(l), do: List.first(l)
  defp normalize_location(l), do: l

  defp get_header(headers, key) do
    headers |> Enum.find_value(fn {k, v} -> if String.downcase(k) == key, do: v end)
  end

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

  defp calculate_remaining_timeout(monitor, start_time) do
    elapsed_ms = calculate_duration(start_time)
    capped = min(monitor.timeout_seconds, @max_timeout_seconds)
    capped * 1000 - elapsed_ms
  end

  defp calculate_duration(start_time) do
    (System.monotonic_time() - start_time)
    |> System.convert_time_unit(:native, :millisecond)
  end
end
