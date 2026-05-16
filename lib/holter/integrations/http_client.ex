defmodule Holter.Integrations.HttpClient do
  @moduledoc """
  Behaviour for the HTTP client used by integration providers.

  The default implementation delegates to Req. In tests, swap it for
  `Holter.Integrations.HttpClientMock` via config.
  """

  def impl, do: Application.get_env(:holter, :integrations_http_client, __MODULE__.HTTP)

  @callback post(url :: String.t(), body :: String.t(), headers :: list()) ::
              {:ok, %{status: integer(), body: term()}} | {:error, term()}

  @callback get(url :: String.t(), headers :: list()) ::
              {:ok, %{status: integer(), body: term()}} | {:error, term()}

  defmodule HTTP do
    @moduledoc false
    @behaviour Holter.Integrations.HttpClient

    alias Holter.Network.Guard

    require Logger

    @receive_timeout Application.compile_env(:holter, :http_receive_timeout, 15_000)

    @impl true
    def post(url, body, headers) do
      with_validated_destination(url, "POST", fn target ->
        uri = URI.parse(url)
        send_post(build_safe_url(uri, target), build_req_opts(uri.host, body, headers))
      end)
    end

    @impl true
    def get(url, headers) do
      with_validated_destination(url, "GET", fn target ->
        uri = URI.parse(url)
        send_get(build_safe_url(uri, target), build_get_opts(uri.host, headers))
      end)
    end

    defp with_validated_destination(url, method, on_allowed) do
      case Guard.validate_destination(url) do
        {:ok, target} -> on_allowed.(target)
        {:error, reason} -> reject_destination(url, method, reason)
      end
    end

    defp send_post(safe_url, opts) do
      safe_url
      |> Req.post(opts)
      |> normalize_response()
    end

    defp send_get(safe_url, opts) do
      safe_url
      |> Req.get(opts)
      |> normalize_response()
    end

    defp normalize_response({:ok, %Req.Response{status: status, body: resp_body}}),
      do: {:ok, %{status: status, body: resp_body}}

    defp normalize_response({:error, reason}), do: {:error, reason}

    defp reject_destination(url, method, reason) do
      Logger.warning("integrations: blocked #{method} to #{inspect(url)} — #{reason}")
      {:error, %RuntimeError{message: "destination rejected: #{reason}"}}
    end

    defp build_safe_url(%URI{host: host} = uri, target) when target == host,
      do: URI.to_string(uri)

    defp build_safe_url(%URI{} = uri, target) do
      ip_host = if String.contains?(target, ":"), do: "[#{target}]", else: target
      URI.to_string(%{uri | host: ip_host})
    end

    defp build_req_opts(original_host, body, headers) do
      Keyword.put(build_get_opts(original_host, headers), :body, body)
    end

    defp build_get_opts(original_host, headers) do
      [
        headers: headers |> Map.new() |> Map.put("host", original_host),
        redirect: false,
        receive_timeout: @receive_timeout,
        connect_options: [
          timeout: 5_000,
          transport_opts: [server_name_indication: to_charlist(original_host)]
        ]
      ]
    end
  end
end
