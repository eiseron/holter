defmodule Holter.Integrations.Engine.CredentialManager do
  @moduledoc false

  @near_expiry_threshold_seconds 300

  @spec classify_token_status(map(), DateTime.t()) :: :valid | :near_expiry | :expired
  def classify_token_status(credentials, now) do
    case parse_expires_at(credentials) do
      {:ok, expires_at} -> do_classify(expires_at, now)
      :error -> :expired
    end
  end

  @spec build_refreshed_credentials(map(), map(), DateTime.t()) :: map()
  def build_refreshed_credentials(existing, refresh_response, now) do
    expires_at =
      case Map.fetch(refresh_response, "expires_in") do
        {:ok, seconds} when is_integer(seconds) ->
          now
          |> DateTime.add(seconds, :second)
          |> DateTime.truncate(:second)
          |> DateTime.to_iso8601()

        _ ->
          Map.get(existing, "expires_at")
      end

    existing
    |> Map.merge(refresh_response)
    |> Map.put("expires_at", expires_at)
    |> Map.delete("expires_in")
  end

  @spec build_connect_attrs(binary(), atom(), map()) :: map()
  def build_connect_attrs(workspace_id, provider, credentials) do
    %{
      workspace_id: workspace_id,
      provider: provider,
      status: :active,
      credentials_encrypted: credentials
    }
  end

  defp parse_expires_at(credentials) do
    with {:ok, iso} when is_binary(iso) <- Map.fetch(credentials, "expires_at"),
         {:ok, dt, _offset} <- DateTime.from_iso8601(iso) do
      {:ok, dt}
    else
      _ -> :error
    end
  end

  defp do_classify(expires_at, now) do
    seconds_remaining = DateTime.diff(expires_at, now, :second)

    cond do
      seconds_remaining <= 0 -> :expired
      seconds_remaining <= @near_expiry_threshold_seconds -> :near_expiry
      true -> :valid
    end
  end
end
