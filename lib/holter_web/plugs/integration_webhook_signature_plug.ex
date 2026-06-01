defmodule HolterWeb.Plugs.IntegrationWebhookSignaturePlug do
  @moduledoc false

  import Plug.Conn

  alias Holter.Integrations.Provider

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"provider" => provider_str}} = conn, _opts) do
    provider = String.to_existing_atom(provider_str)

    case Provider.provider_module(provider) do
      {:ok, provider_mod} -> validate_if_supported(conn, provider_mod)
      {:error, :not_implemented} -> conn
    end
  rescue
    ArgumentError -> conn
  end

  def call(conn, _opts), do: conn

  defp validate_if_supported(conn, provider_mod) do
    if function_exported?(provider_mod, :validate_webhook_signature, 3) do
      run_validation(conn, provider_mod)
    else
      conn
    end
  end

  defp run_validation(conn, provider_mod) do
    case fetch_secret(conn) do
      {:error, :no_secret} ->
        conn
        |> send_resp(401, "no_secret_configured")
        |> halt()

      {:ok, secret} ->
        verify_signature(conn, provider_mod, secret)
    end
  end

  defp verify_signature(conn, provider_mod, secret) do
    raw_body = conn.private[:raw_body] || ""
    headers = conn.req_headers |> Map.new()

    case provider_mod.validate_webhook_signature(raw_body, headers, secret) do
      :ok ->
        put_private(conn, :webhook_verified, true)

      {:error, :timestamp_expired} ->
        conn
        |> send_resp(401, "timestamp_expired")
        |> halt()

      {:error, _} ->
        conn
        |> send_resp(401, "invalid_signature")
        |> halt()
    end
  end

  defp fetch_secret(conn) do
    case conn.private[:webhook_secret] do
      secret when is_binary(secret) and secret != "" -> {:ok, secret}
      _ -> {:error, :no_secret}
    end
  end
end
