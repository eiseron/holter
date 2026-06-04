defmodule Holter.Integrations.Meta.Ads.OAuth do
  @moduledoc false

  alias Holter.Integrations.Engine.CredentialManager
  alias Holter.Integrations.HttpClient

  @scopes ["ads_management", "ads_read"]

  def authorization_url(state) do
    config = Application.get_env(:holter, :meta_ads, [])
    app_id = Keyword.get(config, :app_id, "")
    redirect_uri = Keyword.get(config, :redirect_uri, "")

    params =
      URI.encode_query(%{
        "client_id" => app_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "scope" => Enum.join(@scopes, ","),
        "state" => state
      })

    {:ok, "#{auth_url()}?#{params}"}
  end

  def exchange_code(%{"code" => code} = _params, _state) do
    config = Application.get_env(:holter, :meta_ads, [])
    app_id = Keyword.get(config, :app_id, "")
    app_secret = Keyword.get(config, :app_secret, "")
    redirect_uri = Keyword.get(config, :redirect_uri, "")

    short_lived_params =
      URI.encode_query(%{
        "code" => code,
        "client_id" => app_id,
        "client_secret" => app_secret,
        "redirect_uri" => redirect_uri
      })

    case HttpClient.impl().get("#{token_url()}?#{short_lived_params}", []) do
      {:ok, %{status: 200, body: short_lived_body}} ->
        short_lived_token = Map.get(short_lived_body, "access_token", "")
        exchange_for_long_lived(short_lived_token, app_id, app_secret)

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def exchange_code(_params, _state), do: {:error, :missing_code}

  def refresh_token(credentials) do
    config = Application.get_env(:holter, :meta_ads, [])
    app_id = Keyword.get(config, :app_id, "")
    app_secret = Keyword.get(config, :app_secret, "")
    access_token = Map.get(credentials, "access_token", "")

    exchange_params =
      URI.encode_query(%{
        "grant_type" => "fb_exchange_token",
        "client_id" => app_id,
        "client_secret" => app_secret,
        "fb_exchange_token" => access_token
      })

    case HttpClient.impl().get("#{exchange_url()}?#{exchange_params}", []) do
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
    access_token = Map.get(credentials, "access_token", "")
    body = URI.encode_query(%{"access_token" => access_token})
    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case HttpClient.impl().post(revoke_url(), body, headers) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, {:revoke_failed, status}}
      {:error, reason} -> {:error, {:revoke_failed, reason}}
    end
  end

  defp exchange_for_long_lived(short_lived_token, app_id, app_secret) do
    exchange_params =
      URI.encode_query(%{
        "grant_type" => "fb_exchange_token",
        "client_id" => app_id,
        "client_secret" => app_secret,
        "fb_exchange_token" => short_lived_token
      })

    case HttpClient.impl().get("#{exchange_url()}?#{exchange_params}", []) do
      {:ok, %{status: 200, body: long_lived_body}} ->
        now = DateTime.utc_now()
        credentials = CredentialManager.build_refreshed_credentials(%{}, long_lived_body, now)
        {:ok, credentials}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp auth_url, do: "https://www.facebook.com/#{api_version()}/dialog/oauth"
  defp token_url, do: "https://graph.facebook.com/#{api_version()}/oauth/access_token"
  defp exchange_url, do: "https://graph.facebook.com/#{api_version()}/oauth/access_token"
  defp revoke_url, do: "https://graph.facebook.com/#{api_version()}/me/permissions"

  defp api_version do
    :holter
    |> Application.get_env(:meta_ads, [])
    |> Keyword.get(:api_version, "v25.0")
  end
end
