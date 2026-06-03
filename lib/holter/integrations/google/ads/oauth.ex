defmodule Holter.Integrations.Google.Ads.OAuth do
  @moduledoc false

  alias Holter.Integrations.Engine.CredentialManager
  alias Holter.Integrations.HttpClient

  @token_url "https://oauth2.googleapis.com/token"
  @revoke_url "https://oauth2.googleapis.com/revoke"
  @auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @scopes ["https://www.googleapis.com/auth/adwords"]

  def authorization_url(state) do
    config = Application.get_env(:holter, :google_ads, [])
    client_id = Keyword.get(config, :client_id, "")
    redirect_uri = Keyword.get(config, :redirect_uri, "")

    params =
      URI.encode_query(%{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "scope" => Enum.join(@scopes, " "),
        "state" => state,
        "access_type" => "offline",
        "prompt" => "consent"
      })

    {:ok, "#{@auth_url}?#{params}"}
  end

  def exchange_code(%{"code" => code} = _params, _state) do
    config = Application.get_env(:holter, :google_ads, [])

    body =
      URI.encode_query(%{
        "code" => code,
        "client_id" => Keyword.get(config, :client_id, ""),
        "client_secret" => Keyword.get(config, :client_secret, ""),
        "redirect_uri" => Keyword.get(config, :redirect_uri, ""),
        "grant_type" => "authorization_code"
      })

    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case HttpClient.impl().post(@token_url, body, headers) do
      {:ok, %{status: 200, body: token_body}} ->
        now = DateTime.utc_now()
        credentials = CredentialManager.build_refreshed_credentials(%{}, token_body, now)
        {:ok, credentials}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def exchange_code(_params, _state), do: {:error, :missing_code}

  def refresh_token(credentials) do
    config = Application.get_env(:holter, :google_ads, [])
    refresh_token_value = Map.get(credentials, "refresh_token", "")

    body =
      URI.encode_query(%{
        "refresh_token" => refresh_token_value,
        "client_id" => Keyword.get(config, :client_id, ""),
        "client_secret" => Keyword.get(config, :client_secret, ""),
        "grant_type" => "refresh_token"
      })

    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case HttpClient.impl().post(@token_url, body, headers) do
      {:ok, %{status: 200, body: token_body}} ->
        now = DateTime.utc_now()

        new_credentials =
          CredentialManager.build_refreshed_credentials(credentials, token_body, now)

        {:ok, new_credentials}

      {:ok, %{status: 401}} ->
        {:error, :revoked}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def revoke_token(credentials) do
    token = Map.get(credentials, "access_token", "")
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    body = URI.encode_query(%{"token" => token})

    case HttpClient.impl().post(@revoke_url, body, headers) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, {:revoke_failed, status}}
      {:error, reason} -> {:error, {:revoke_failed, reason}}
    end
  end
end
