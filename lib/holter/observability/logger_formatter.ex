defmodule Holter.Observability.LoggerFormatter do
  @moduledoc """
  Custom LoggerJSON formatter that scrubs sensitive data from metadata.
  """
  @behaviour LoggerJSON.Formatter

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
    scrubbed_metadata = scrub_map(log_event.metadata)
    log_event = %{log_event | metadata: scrubbed_metadata}

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
end
