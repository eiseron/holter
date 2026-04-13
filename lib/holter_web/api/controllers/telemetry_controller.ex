defmodule HolterWeb.Api.TelemetryController do
  @moduledoc """
  Receives telemetry logs from client-side.
  """
  use HolterWeb, :controller
  require Logger

  def log(conn, %{"level" => level, "message" => message} = params) do
    if same_origin?(conn) do
      metadata = [
        client_side: true,
        stack: params["stack"],
        url: params["url"]
      ]

      case String.downcase(level) do
        "error" -> Logger.error(message, metadata)
        "warn" -> Logger.warning(message, metadata)
        _ -> Logger.info(message, metadata)
      end

      send_resp(conn, 204, "")
    else
      send_resp(conn, 403, "")
    end
  end

  defp same_origin?(conn) do
    origin = get_req_header(conn, "origin") |> List.first()
    host = HolterWeb.Endpoint.url()

    is_nil(origin) or String.starts_with?(origin, host) or String.contains?(origin, "localhost")
  end
end
