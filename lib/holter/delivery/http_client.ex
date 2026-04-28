defmodule Holter.Delivery.HttpClient do
  @moduledoc """
  Behaviour for the HTTP client used by the delivery engine.
  """

  def impl, do: Application.get_env(:holter, :delivery_http_client, __MODULE__.HTTP)

  @callback post(url :: String.t(), body :: String.t(), headers :: list()) ::
              {:ok, %{status: integer()}} | {:error, Exception.t()}

  defmodule HTTP do
    @moduledoc false
    @behaviour Holter.Delivery.HttpClient

    alias Holter.Network.Guard

    require Logger

    @receive_timeout Application.compile_env(:holter, :http_receive_timeout, 15_000)

    @impl true
    def post(url, body, headers) do
      case Guard.validate_destination(url) do
        {:ok, target} ->
          uri = URI.parse(url)
          safe_url = build_safe_url(uri, target)
          opts = build_req_opts(uri.host, body, headers)

          case Req.post(safe_url, opts) do
            {:ok, %Req.Response{status: status}} -> {:ok, %{status: status}}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          log_and_reject(url, reason)
      end
    end

    defp build_safe_url(%URI{host: host} = uri, target) when target == host,
      do: URI.to_string(uri)

    defp build_safe_url(%URI{} = uri, target) do
      ip_host = if String.contains?(target, ":"), do: "[#{target}]", else: target
      URI.to_string(%{uri | host: ip_host})
    end

    defp build_req_opts(original_host, body, headers) do
      [
        body: body,
        headers: headers |> Map.new() |> Map.put("host", original_host),
        redirect: false,
        receive_timeout: @receive_timeout,
        connect_options: [
          timeout: 5_000,
          transport_opts: [server_name_indication: to_charlist(original_host)]
        ]
      ]
    end

    defp log_and_reject(url, reason) do
      Logger.warning("delivery: blocked dispatch to #{inspect(url)} — #{reason}")
      {:error, %RuntimeError{message: "destination rejected: #{reason}"}}
    end
  end
end
