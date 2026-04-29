defmodule Holter.Monitoring.MonitorClient do
  @moduledoc """
  Behaviour for the HTTP client used by the monitoring engine.
  """

  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  @callback get_ssl_expiration(String.t()) :: {:ok, DateTime.t()} | {:error, any()}
  @callback get_domain_expiration(String.t()) :: {:ok, DateTime.t()} | {:error, any()}

  defmodule HTTP do
    @moduledoc """
    Default HTTP implementation using Req and Erlang :ssl.
    """
    @behaviour Holter.Monitoring.MonitorClient

    alias Holter.Monitoring.{CertificateParser, Rdap}

    @max_body_bytes 5 * 1024 * 1024

    def body_within_limit?(body, limit \\ @max_body_bytes)

    def body_within_limit?(body, limit) when is_binary(body),
      do: byte_size(body) <= limit

    def body_within_limit?(_body, _limit), do: true

    @impl true
    def request(opts) do
      opts
      |> Keyword.put_new(:user_agent, build_user_agent())
      |> Keyword.put_new(:compressed, false)
      |> Keyword.put_new(:retry, fn
        _request, %Req.Response{} -> false
        _request, _exception -> true
      end)
      |> Req.request()
      |> check_body_size()
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

    @impl true
    def get_domain_expiration(host) when is_binary(host),
      do: Rdap.get_expiration(host)

    defp check_body_size({:ok, response}) do
      if body_within_limit?(response.body) do
        {:ok, response}
      else
        size = byte_size(response.body)

        {:error,
         %RuntimeError{
           message: "Response body too large (#{size} bytes, limit #{@max_body_bytes})"
         }}
      end
    end

    defp check_body_size(error), do: error

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
