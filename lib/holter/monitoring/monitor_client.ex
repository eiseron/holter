defmodule Holter.Monitoring.MonitorClient do
  @moduledoc """
  Behaviour for the HTTP client used by the monitoring engine.
  """

  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  @callback get_ssl_expiration(String.t()) :: {:ok, DateTime.t()} | {:error, any()}

  defmodule HTTP do
    @moduledoc """
    Default HTTP implementation using Req and Erlang :ssl.
    """
    @behaviour Holter.Monitoring.MonitorClient

    alias Holter.Monitoring.CertificateParser

    @impl true
    def request(opts) do
      opts
      |> Keyword.put_new(:user_agent, build_user_agent())
      |> Keyword.put_new(:retry, fn
        _request, %Req.Response{} -> false
        _request, _exception -> true
      end)
      |> Req.request()
    end

    @impl true
    def get_ssl_expiration(url) do
      uri = URI.parse(url)
      host = to_charlist(uri.host)
      port = uri.port || 443

      case :ssl.connect(host, port, [verify: :verify_none], 5000) do
        {:ok, socket} ->
          result = fetch_expiration_from_socket(socket)
          :ssl.close(socket)
          result

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp build_user_agent do
      version = Application.spec(:holter, :vsn) |> to_string()
      app_domain = System.get_env("APP_DOMAIN", "holter.dev")
      "Holter/#{version} (+https://#{app_domain})"
    end

    defp fetch_expiration_from_socket(socket) do
      case :ssl.peercert(socket) do
        {:ok, cert} ->
          {:ok, CertificateParser.parse_expiry(cert)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
