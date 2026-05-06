defmodule Holter.I18n.Locale do
  @moduledoc """
  Pure transformer for locale primitives. Single source of truth for the
  list of supported locales, the application default, and the parsing of
  the `Accept-Language` HTTP header.

  The supported list is derived from `Gettext.known_locales/1` — every
  language directory under `priv/gettext/` is automatically a supported
  locale. The default locale comes from
  `config :holter, Holter.I18n.Locale, default_locale: ...` — a domain
  config that the application boot also propagates to the Gettext
  backend, so this module is the single source of truth.

  No `Repo`, no clock, no app-env writes.
  """

  @doc """
  Returns the list of supported locales as Gettext-formatted strings.
  Auto-discovered from `priv/gettext/`.
  """
  def supported, do: Gettext.known_locales(HolterWeb.Gettext)

  @doc """
  Returns the application's fallback locale from
  `config :holter, Holter.I18n.Locale, :default_locale`. Raises if the
  configuration is missing — every environment must pin a default, so
  absence is a deployment-misconfiguration error.
  """
  def default do
    Application.get_env(:holter, __MODULE__, [])
    |> Keyword.fetch!(:default_locale)
  end

  @doc "True when the value is one of `supported/0`."
  def valid?(value) when is_binary(value), do: value in supported()
  def valid?(_), do: false

  @doc """
  Picks the best supported locale from an `Accept-Language` header.
  Returns `nil` when no entry matches.

  Implements the BCP-47 normalization the rest of the codebase expects:
  `pt-BR`/`pt-br`/`pt_BR` all resolve to `pt_BR`. Bare language codes
  without a region (e.g. `pt`) do NOT match `pt_BR` — the caller should
  fall through to the next resolver tier.

  Quality factors are honored: entries are sorted by `q=` descending
  (default `q=1.0`), and the first match wins.
  """
  def parse_accept_language(header) when is_binary(header) do
    header
    |> String.split(",")
    |> Enum.map(&parse_entry/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_locale, q} -> q end, :desc)
    |> Enum.find_value(fn {locale, _q} -> if valid?(locale), do: locale end)
  end

  def parse_accept_language(_), do: nil

  defp parse_entry(raw) do
    case String.split(raw, ";", parts: 2) |> Enum.map(&String.trim/1) do
      [tag] -> build_entry(tag, 1.0)
      [tag, params] -> build_entry(tag, extract_quality(params))
      _ -> nil
    end
  end

  defp build_entry("", _q), do: nil
  defp build_entry(tag, q), do: {normalize_tag(tag), q}

  defp normalize_tag(tag) do
    case String.split(tag, ["-", "_"], parts: 2) do
      [lang] ->
        String.downcase(lang)

      [lang, region] ->
        String.downcase(lang) <> "_" <> String.upcase(region)
    end
  end

  defp extract_quality(params) do
    params
    |> String.split(";")
    |> Enum.find_value(1.0, &quality_from_param/1)
  end

  defp quality_from_param(param) do
    case param |> String.trim() |> String.split("=", parts: 2) do
      ["q", value] ->
        case value |> String.trim() |> Float.parse() do
          {q, _} -> q
          :error -> 1.0
        end

      _ ->
        nil
    end
  end
end
