defmodule Holter.Observability.LoggerFormatter do
  @moduledoc """
  Custom LoggerJSON formatter that scrubs sensitive data and ensures system metadata.
  """
  @behaviour LoggerJSON.Formatter

  alias Holter.Observability
  alias LoggerJSON.Formatters.Basic

  @sensitive_keys ~w(
    password
    password_confirmation
    secret
    secret_key
    token
    api_key
    authorization
    cookie
    x-csrf-token
    x-session-id
  )s

  @impl true
  def format(log_event, opts) do
    log_event = %{log_event | meta: process_meta(log_event.meta)}
    Basic.format(log_event, opts)
  end

  defp process_meta(meta) do
    Observability.system_versions()
    |> Map.merge(Map.new(meta))
    |> scrub_map()
  end

  defp scrub_map(metadata) when is_list(metadata) do
    metadata
    |> Map.new()
    |> scrub_map()
    |> Map.to_list()
  end

  defp scrub_map(metadata) when is_map(metadata) do
    Enum.into(metadata, %{}, fn {k, v} ->
      key_str = k |> to_string() |> String.downcase()

      cond do
        key_str in @sensitive_keys -> {k, "[FILTERED]"}
        is_map(v) -> {k, scrub_map(v)}
        true -> {k, v}
      end
    end)
  end

  defp scrub_map(v), do: v

  if Mix.env() == :test do
    def process_meta_for_test(meta), do: process_meta(meta)
  end
end
