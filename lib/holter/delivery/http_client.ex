defmodule Holter.Delivery.HttpClient do
  @moduledoc """
  Behaviour for the HTTP client used by the delivery engine.
  """

  def impl, do: Application.get_env(:holter, :delivery_http_client, HTTP)

  @callback post(url :: String.t(), body :: String.t(), headers :: list()) ::
              {:ok, %{status: integer()}} | {:error, Exception.t()}

  defmodule HTTP do
    @moduledoc false
    @behaviour Holter.Delivery.HttpClient

    @receive_timeout Application.compile_env(:holter, :http_receive_timeout, 15_000)

    @impl true
    def post(url, body, headers) do
      case Req.post(url,
             body: body,
             headers: Map.new(headers),
             redirect: false,
             receive_timeout: @receive_timeout,
             connect_options: [timeout: 5_000]
           ) do
        {:ok, %Req.Response{status: status}} -> {:ok, %{status: status}}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
