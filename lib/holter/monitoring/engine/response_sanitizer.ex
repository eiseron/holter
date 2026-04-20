defmodule Holter.Monitoring.Engine.ResponseSanitizer do
  @moduledoc false

  def filter_headers(headers) do
    interesting = ["server", "cf-ray", "content-type", "cache-control", "x-cache", "via"]

    headers
    |> Enum.into(%{})
    |> Map.take(interesting)
    |> Map.new(fn {k, v} ->
      {k, v |> sanitize_for_db() |> mask_secrets() |> truncate_value(1024)}
    end)
  end

  def clean_body_snippet(body, content_type) do
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

  def mask_secrets(value) when is_binary(value) do
    value
    |> String.replace(~r"Bearer\s+[a-zA-Z0-9\-\._~+/]+=*"i, "Bearer [REDACTED]")
    |> String.replace(~r"eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+(\.[a-zA-Z0-9\-_]+)?"i, "[REDACTED]")
    |> String.replace(
      ~r"(api_key|access_token|auth_token|secret|password|key)=[^&\s]+"i,
      "\\1=[REDACTED]"
    )
    |> String.replace(~r"(sk|pk)_(live|test)_[a-zA-Z0-9]{20,}"i, "[REDACTED]")
  end

  def mask_secrets(value), do: value

  def sanitize_for_db(value) when is_binary(value) do
    value
    |> String.replace("\0", "")
    |> String.replace(~r"[\r\n]+", " ")
  end

  def sanitize_for_db(value), do: value

  def truncate_value(v, limit) when is_binary(v) do
    if byte_size(v) > limit, do: String.slice(v, 0, limit), else: v
  end

  def truncate_value(v, _limit), do: v

  def strip_html_tags(html) do
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

  def normalize_whitespace(text) do
    text
    |> String.replace(~r"\s+", " ")
    |> String.trim()
  end

  def ensure_utf8(text) do
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
end
