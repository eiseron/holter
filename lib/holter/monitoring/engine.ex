defmodule Holter.Monitoring.Engine do
  @moduledoc """
  Core monitoring logic detached from Oban workers.
  This service handles response processing, keyword validation,
  incident lifecycle, and monitor log creation.
  """

  alias Holter.Monitoring
  alias Holter.Monitoring.{Incidents, Monitor, Monitors}
  use Gettext, backend: HolterWeb.Gettext

  def process_response(monitor, response, metadata) do
    Logger.metadata(
      monitor_id: monitor.id,
      workspace_id: monitor.workspace_id,
      context: :monitoring_check
    )

    ip = extract_ip(response)
    metadata = Map.put(metadata, :ip, ip)

    if restricted_ip?(ip) do
      handle_restricted_ip(monitor, response, metadata)
    else
      perform_full_validation(monitor, response, metadata)
    end
  end

  defp handle_restricted_ip(monitor, response, metadata) do
    finalize_check(
      monitor,
      %{
        check_status: :down,
        log_status: :down,
        status_code: response.status,
        duration_ms: metadata.duration_ms,
        error_msg: gettext("Access to restricted internal address blocked"),
        snippet: nil,
        headers: nil,
        ip: metadata.ip,
        redirect_count: Map.get(metadata, :redirects, 0),
        last_redirect_url: Map.get(metadata, :last_url),
        redirect_list: Map.get(metadata, :redirect_list, []),
        defacement_in_body: false
      }
    )
  end

  defp perform_full_validation(monitor, response, metadata) do
    content_type = get_header(response.headers, "content-type")
    body = normalize_body(response.body)
    search_body = prepare_search_body(body, content_type)

    {positive_ok, negative_ok, missing_keywords, matched_forbidden} =
      validate_keywords(search_body, monitor)

    check_status = determine_check_status(response.status, positive_ok, negative_ok)

    error_msg =
      determine_error_message(%{
        status: response.status,
        positive_ok: positive_ok,
        negative_ok: negative_ok,
        missing_keywords: missing_keywords,
        matched_forbidden: matched_forbidden
      })

    defacement_in_body = detect_defacement_indicators(search_body)

    response_data = %{body: body, content_type: content_type, headers: response.headers}
    {headers, snippet} = maybe_collect_evidence(monitor, check_status, response_data)

    finalize_check(
      monitor,
      %{
        check_status: check_status,
        log_status: check_status,
        status_code: response.status,
        duration_ms: metadata.duration_ms,
        error_msg: error_msg,
        snippet: snippet,
        headers: headers,
        ip: metadata.ip,
        redirect_count: Map.get(metadata, :redirects, 0),
        last_redirect_url: Map.get(metadata, :last_url),
        redirect_list: Map.get(metadata, :redirect_list, []),
        defacement_in_body: defacement_in_body
      }
    )
  end

  defp prepare_search_body(body, content_type) do
    if html?(content_type), do: strip_html_tags(body), else: body
  end

  defp maybe_collect_evidence(monitor, check_status, response_data) do
    if check_status != monitor.health_status do
      {filter_headers(response_data.headers),
       clean_body_snippet(response_data.body, response_data.content_type)}
    else
      {nil, nil}
    end
  end

  def handle_failure(monitor, error, duration_ms) do
    finalize_check(monitor, %{
      check_status: :down,
      log_status: :down,
      status_code: nil,
      duration_ms: duration_ms,
      error_msg: Exception.message(error),
      snippet: nil,
      headers: nil,
      ip: nil,
      defacement_in_body: false
    })
  end

  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_map(body), do: Jason.encode!(body)
  defp normalize_body(_), do: ""

  defp validate_keywords(body, monitor) do
    downcase_body = String.downcase(body)
    {positive_ok, missing} = validate_positive(downcase_body, monitor.keyword_positive)
    {negative_ok, matched} = validate_negative(downcase_body, monitor.keyword_negative)
    {positive_ok, negative_ok, missing, matched}
  end

  defp determine_check_status(status, positive_ok, _negative_ok)
       when status < 200 or status >= 300 or not positive_ok,
       do: :down

  defp determine_check_status(_status, _positive_ok, false), do: :compromised
  defp determine_check_status(_status, _positive_ok, _negative_ok), do: :up

  defp determine_error_message(%{status: s}) when s < 200 or s >= 300,
    do: gettext("HTTP Error: %{status}", status: s)

  defp determine_error_message(%{positive_ok: false, missing_keywords: missing}) do
    keywords = Enum.map_join(missing, ", ", &~s("#{&1}"))
    gettext("Missing required keywords: %{keywords}", keywords: keywords)
  end

  defp determine_error_message(%{negative_ok: false, matched_forbidden: matched}) do
    keywords = Enum.map_join(matched, ", ", &~s("#{&1}"))
    gettext("Found forbidden keywords: %{keywords}", keywords: keywords)
  end

  defp determine_error_message(_), do: nil

  defp finalize_check(monitor, params) do
    now = DateTime.utc_now()
    snapshot = Monitor.capture_snapshot(monitor)

    handle_incident_logic(monitor, %{
      check_status: params.check_status,
      error_msg: params.error_msg,
      snapshot: snapshot,
      now: now,
      defacement_in_body: Map.get(params, :defacement_in_body, false)
    })

    open_incidents = Monitoring.list_open_incidents(monitor.id)
    {active_incident_id, incident_status} = pick_active_incident(open_incidents)

    effective_log_status =
      if Monitors.status_severity(incident_status) > Monitors.status_severity(params.log_status),
        do: incident_status,
        else: params.log_status

    record_monitor_log(%{
      monitor_id: monitor.id,
      status: effective_log_status,
      incident_id: active_incident_id,
      status_code: params.status_code,
      latency_ms: params.duration_ms,
      error_message: params.error_msg,
      response_snippet: params.snippet,
      response_headers: params.headers,
      response_ip: params.ip,
      region: get_region(),
      redirect_count: params[:redirect_count],
      last_redirect_url: params[:last_redirect_url],
      redirect_list: params[:redirect_list] || [],
      checked_at: now,
      monitor_snapshot: snapshot
    })

    updated_monitor =
      update_monitor_state(monitor, %{
        check_status: params.check_status,
        effective_status: effective_log_status,
        now: now
      })

    {:ok, updated_monitor}
  end

  defp pick_active_incident([]), do: {nil, :unknown}

  defp pick_active_incident(incidents) do
    incident =
      Enum.max_by(incidents, fn i ->
        Monitors.status_severity(Incidents.incident_to_health(i))
      end)

    {incident.id, Incidents.incident_to_health(incident)}
  end

  defp handle_incident_logic(monitor, %{check_status: :up, now: now}) do
    resolve_if_open(monitor, :downtime, now)
    resolve_if_open(monitor, :defacement, now)
  end

  defp handle_incident_logic(monitor, %{check_status: :down} = metadata) do
    resolve_if_open(monitor, :defacement, metadata.now)
    open_if_missing(monitor, :downtime, metadata)
    if Map.get(metadata, :defacement_in_body), do: open_if_missing(monitor, :defacement, metadata)
  end

  defp handle_incident_logic(monitor, %{check_status: :compromised} = metadata) do
    resolve_if_open(monitor, :downtime, metadata.now)
    open_if_missing(monitor, :defacement, metadata)
  end

  defp resolve_if_open(monitor, type, now) do
    case Monitoring.get_open_incident(monitor.id, type) do
      nil -> :ok
      incident -> Monitoring.resolve_incident(incident, now)
    end
  end

  defp open_if_missing(monitor, type, metadata) do
    case Monitoring.get_open_incident(monitor.id, type) do
      nil -> create_incident_idempotent(monitor, type, metadata)
      _ -> :ok
    end
  end

  defp create_incident_idempotent(monitor, type, metadata) do
    result =
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: type,
        started_at: metadata.now,
        root_cause: metadata.error_msg,
        monitor_snapshot: metadata.snapshot
      })

    if Monitoring.open_incident_already_exists?(result), do: :ok, else: result
  end

  defp update_monitor_state(monitor, %{
         check_status: check_status,
         effective_status: effective_status,
         now: now
       }) do
    {:ok, updated_monitor} =
      Monitoring.update_monitor(monitor, %{
        health_status: effective_status,
        last_checked_at: now,
        last_success_at: if(check_status == :up, do: now, else: monitor.last_success_at)
      })

    updated_monitor
  end

  defp record_monitor_log(attrs), do: Monitoring.create_monitor_log(attrs)

  @defacement_indicators ["hacked", "defaced", "owned by", "you've been pwned"]

  defp detect_defacement_indicators(body) do
    lower = String.downcase(body)
    Enum.any?(@defacement_indicators, &String.contains?(lower, &1))
  end

  defp get_region, do: System.get_env("MONITOR_REGION", "br-sp-1")

  defp validate_positive(_body, empty) when empty in [nil, []], do: {true, []}

  defp validate_positive(body, keywords) do
    missing = Enum.reject(keywords, &String.contains?(body, String.downcase(&1)))
    {missing == [], missing}
  end

  defp validate_negative(_body, empty) when empty in [nil, []], do: {true, []}

  defp validate_negative(body, keywords) do
    matched = Enum.filter(keywords, &String.contains?(body, String.downcase(&1)))
    {matched == [], matched}
  end

  defp restricted_ip?(nil), do: false

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

  defp filter_headers(headers) do
    interesting = ["server", "cf-ray", "content-type", "cache-control", "x-cache", "via"]

    headers
    |> Enum.into(%{})
    |> Map.take(interesting)
    |> Map.new(fn {k, v} ->
      {k, v |> sanitize_for_db() |> mask_secrets() |> truncate_value(1024)}
    end)
  end

  defp mask_secrets(value) when is_binary(value) do
    value
    |> String.replace(~r"Bearer\s+[a-zA-Z0-9\-\._~+/]+=*"i, "Bearer [REDACTED]")
    |> String.replace(~r"eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+(\.[a-zA-Z0-9\-_]+)?"i, "[REDACTED]")
    |> String.replace(
      ~r"(api_key|access_token|auth_token|secret|password|key)=[^&\s]+"i,
      "\\1=[REDACTED]"
    )
    |> String.replace(~r"(sk|pk)_(live|test)_[a-zA-Z0-9]{20,}"i, "[REDACTED]")
  end

  defp mask_secrets(value), do: value

  defp sanitize_for_db(value) when is_binary(value) do
    value
    |> String.replace("\0", "")
    |> String.replace(~r"[\r\n]+", " ")
  end

  defp sanitize_for_db(value), do: value

  defp truncate_value(v, limit) when is_binary(v) do
    if byte_size(v) > limit, do: String.slice(v, 0, limit), else: v
  end

  defp truncate_value(v, _limit), do: v

  defp extract_ip(response) do
    case response.private[:req_remote_addr] do
      nil -> nil
      addr -> :inet.ntoa(addr) |> to_string()
    end
  end

  defp get_header(headers, key) do
    headers |> Enum.find_value(fn {k, v} -> if k == key, do: v end)
  end

  defp html?(content_type) do
    type =
      content_type
      |> List.wrap()
      |> List.first()
      |> Kernel.||("")
      |> String.downcase()

    String.contains?(type, "html")
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
      |> sanitize_for_db()
      |> mask_secrets()
      |> ensure_utf8()
      |> String.slice(0, 512)
    else
      "Binary content (skipped)"
    end
  end

  defp ensure_utf8(text) do
    if String.valid?(text) do
      text
    else
      text
      |> :binary.bin_to_list()
      |> Enum.map(fn
        b when b < 128 -> b
        _ -> ??
      end)
      |> List.to_string()
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
        html |> String.replace(~r"<[^>]*>"U, " ")
    end
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r"\s+", " ")
    |> String.trim()
  end
end
