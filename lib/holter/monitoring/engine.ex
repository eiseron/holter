defmodule Holter.Monitoring.Engine do
  @moduledoc """
  Core monitoring logic detached from Oban workers.
  This service handles response processing, keyword validation, 
  incident lifecycle, and monitor log creation.
  """

  alias Holter.Monitoring

  def process_response(monitor, response, duration_ms) do
    body = normalize_body(response.body)
    {positive_ok, negative_ok} = validate_keywords(body, monitor)

    check_status = determine_check_status(response.status, positive_ok, negative_ok)
    log_status = determine_log_status(check_status)

    error_msg = determine_error_message(response.status, positive_ok, negative_ok)

    {headers, snippet, ip} =
      if check_status != monitor.health_status do
        {
          filter_headers(response.headers),
          clean_body_snippet(body, get_header(response.headers, "content-type")),
          extract_ip(response)
        }
      else
        {nil, nil, nil}
      end

    finalize_check(monitor, %{
      check_status: check_status,
      log_status: log_status,
      status_code: response.status,
      duration_ms: duration_ms,
      error_msg: error_msg,
      snippet: snippet,
      headers: headers,
      ip: ip
    })
  end

  def handle_failure(monitor, error, duration_ms) do
    finalize_check(monitor, %{
      check_status: :down,
      log_status: :failure,
      status_code: nil,
      duration_ms: duration_ms,
      error_msg: Exception.message(error),
      snippet: nil,
      headers: nil,
      ip: nil
    })
  end

  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_map(body), do: Jason.encode!(body)
  defp normalize_body(_), do: ""

  defp validate_keywords(body, monitor) do
    {
      validate_positive(body, monitor.keyword_positive),
      validate_negative(body, monitor.keyword_negative)
    }
  end

  defp determine_check_status(status, positive_ok, _negative_ok)
       when status < 200 or status >= 400 or not positive_ok,
       do: :down

  defp determine_check_status(_status, _positive_ok, false), do: :compromised
  defp determine_check_status(_status, _positive_ok, _negative_ok), do: :up

  defp determine_log_status(:up), do: :success
  defp determine_log_status(_), do: :failure

  defp determine_error_message(status, _, _) when status < 200 or status >= 400,
    do: "HTTP Error: #{status}"

  defp determine_error_message(_, false, _), do: "Missing required keywords"
  defp determine_error_message(_, _, false), do: "Found forbidden keywords"
  defp determine_error_message(_, _, _), do: nil

  defp finalize_check(monitor, params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    handle_incident_logic(monitor, params.check_status, params.error_msg, now)
    updated_monitor = update_monitor_state(monitor, params.check_status, now)

    record_monitor_log(%{
      monitor_id: monitor.id,
      status: params.log_status,
      status_code: params.status_code,
      latency_ms: params.duration_ms,
      error_message: params.error_msg,
      response_snippet: params.snippet,
      response_headers: params.headers,
      response_ip: params.ip,
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

  defp record_monitor_log(attrs), do: Monitoring.create_monitor_log(attrs)

  defp get_region, do: System.get_env("MONITOR_REGION", "br-sp-1")

  defp validate_positive(_body, empty) when empty in [nil, []], do: true
  defp validate_positive(body, keywords), do: Enum.all?(keywords, &String.contains?(body, &1))

  defp validate_negative(_body, empty) when empty in [nil, []], do: true
  defp validate_negative(body, keywords), do: not Enum.any?(keywords, &String.contains?(body, &1))

  defp filter_headers(headers) do
    interesting = ["server", "cf-ray", "content-type", "cache-control", "x-cache", "via"]

    headers
    |> Enum.into(%{})
    |> Map.take(interesting)
  end

  defp extract_ip(response) do
    case response.private[:req_remote_addr] do
      nil -> nil
      addr -> :inet.ntoa(addr) |> to_string()
    end
  end

  defp get_header(headers, key) do
    headers |> Enum.find_value(fn {k, v} -> if k == key, do: v end)
  end

  defp clean_body_snippet(body, content_type) do
    type =
      content_type
      |> List.wrap()
      |> List.first()
      |> Kernel.||("text/plain")

    if String.contains?(type, ["text", "json", "xml"]) do
      body
      |> strip_html_tags()
      |> normalize_whitespace()
      |> String.slice(0, 512)
    else
      "Binary content (skipped)"
    end
  end

  defp strip_html_tags(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        document
        |> Floki.filter_out("script")
        |> Floki.filter_out("style")
        |> Floki.text(sep: " ")

      _ ->
        html |> String.replace(~r/<[^>]*>/, " ")
    end
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
