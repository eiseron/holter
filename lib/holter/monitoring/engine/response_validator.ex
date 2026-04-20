defmodule Holter.Monitoring.Engine.ResponseValidator do
  @moduledoc false

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Monitoring.Engine.ResponseSanitizer

  @defacement_indicators ["hacked", "defaced", "owned by", "you've been pwned"]

  def validate_response(monitor, response, metadata) do
    content_type = get_header(response.headers, "content-type")
    body = normalize_body(response.body)
    search_body = prepare_search_body(body, content_type)

    {positive_ok, negative_ok, missing_keywords, matched_forbidden} =
      validate_keywords(search_body, monitor)

    check_status = determine_check_status(response.status, positive_ok, negative_ok)

    downtime_error_msg =
      determine_downtime_error_msg(response.status, positive_ok, missing_keywords)

    defacement_error_msg = determine_defacement_error_msg(negative_ok, matched_forbidden)

    error_msg =
      if check_status == :compromised, do: defacement_error_msg, else: downtime_error_msg

    defacement_in_body = detect_defacement_indicators(search_body)

    response_data = %{body: body, content_type: content_type, headers: response.headers}
    {headers, snippet} = maybe_collect_evidence(monitor, check_status, response_data)

    %{
      check_status: check_status,
      log_status: check_status,
      status_code: response.status,
      duration_ms: metadata.duration_ms,
      error_msg: error_msg,
      positive_ok: positive_ok,
      downtime_error_msg: downtime_error_msg,
      defacement_error_msg: defacement_error_msg,
      snippet: snippet,
      headers: headers,
      ip: metadata.ip,
      redirect_count: Map.get(metadata, :redirects, 0),
      last_redirect_url: Map.get(metadata, :last_url),
      redirect_list: Map.get(metadata, :redirect_list, []),
      defacement_in_body: defacement_in_body
    }
  end

  def validate_keywords(body, monitor) do
    downcase_body = String.downcase(body)
    {positive_ok, missing} = validate_positive(downcase_body, monitor.keyword_positive)
    {negative_ok, matched} = validate_negative(downcase_body, monitor.keyword_negative)
    {positive_ok, negative_ok, missing, matched}
  end

  def validate_positive(_body, empty) when empty in [nil, []], do: {true, []}

  def validate_positive(body, keywords) do
    missing = Enum.reject(keywords, &String.contains?(body, String.downcase(&1)))
    {missing == [], missing}
  end

  def validate_negative(_body, empty) when empty in [nil, []], do: {true, []}

  def validate_negative(body, keywords) do
    matched = Enum.filter(keywords, &String.contains?(body, String.downcase(&1)))
    {matched == [], matched}
  end

  def determine_check_status(status, _positive_ok, _negative_ok)
      when status < 200 or status >= 300,
      do: :down

  def determine_check_status(_status, _positive_ok, false), do: :compromised
  def determine_check_status(_status, false, _negative_ok), do: :down
  def determine_check_status(_status, _positive_ok, _negative_ok), do: :up

  def determine_downtime_error_msg(status, _positive_ok, _missing)
      when status < 200 or status >= 300,
      do: gettext("HTTP Error: %{status}", status: status)

  def determine_downtime_error_msg(_status, false, missing) do
    keywords = Enum.map_join(missing, ", ", &~s("#{&1}"))
    gettext("Missing required keywords: %{keywords}", keywords: keywords)
  end

  def determine_downtime_error_msg(_status, _positive_ok, _missing), do: nil

  def determine_defacement_error_msg(false, matched) do
    keywords = Enum.map_join(matched, ", ", &~s("#{&1}"))
    gettext("Found forbidden keywords: %{keywords}", keywords: keywords)
  end

  def determine_defacement_error_msg(_negative_ok, _matched), do: nil

  def detect_defacement_indicators(body) do
    lower = String.downcase(body)
    Enum.any?(@defacement_indicators, &String.contains?(lower, &1))
  end

  def prepare_search_body(body, content_type) do
    if html?(content_type), do: ResponseSanitizer.strip_html_tags(body), else: body
  end

  def normalize_body(body) when is_binary(body), do: body
  def normalize_body(body) when is_map(body), do: Jason.encode!(body)
  def normalize_body(_), do: ""

  def html?(content_type) do
    type =
      content_type
      |> List.wrap()
      |> List.first()
      |> Kernel.||("")
      |> String.downcase()

    String.contains?(type, "html")
  end

  def get_header(headers, key) do
    headers |> Enum.find_value(fn {k, v} -> if k == key, do: v end)
  end

  def maybe_collect_evidence(monitor, check_status, response_data) do
    if check_status != monitor.health_status do
      {ResponseSanitizer.filter_headers(response_data.headers),
       ResponseSanitizer.clean_body_snippet(response_data.body, response_data.content_type)}
    else
      {nil, nil}
    end
  end
end
