defmodule Holter.Observability.LoggerFormatter do
  @moduledoc """
  Custom LoggerJSON formatter that scrubs sensitive data and ensures system metadata.
  """
  @behaviour LoggerJSON.Formatter

  alias LoggerJSON.Formatters.Basic
  alias Holter.Observability

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
    # 1. Ensure system versions are present in metadata
    enriched_meta = Map.merge(Observability.system_versions(), log_event.meta)
    
    # 2. Scrub sensitive data
    scrubbed_meta = scrub_map(enriched_meta)
    
    # 3. Rebuild event and format
    log_event = %{log_event | meta: scrubbed_meta}
    Basic.format(log_event, opts)
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
    def scrub_map_for_test(metadata), do: scrub_map(metadata)
  end
end
