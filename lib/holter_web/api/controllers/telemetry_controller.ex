defmodule HolterWeb.Api.TelemetryController do
  @moduledoc """
  Receives telemetry logs from client-side.
  """
  use HolterWeb, :controller
  require Logger

  def log(conn, %{"level" => level, "message" => message} = params) do
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
  end
end
