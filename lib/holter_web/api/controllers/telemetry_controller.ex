defmodule HolterWeb.Api.TelemetryController do
  @moduledoc """
  Receives telemetry logs from client-side.
  """
  use HolterWeb, :controller
  require Logger

  def log(conn, params) do
    with {:ok, level} <- extract_string_param(params, "level"),
         {:ok, message} <- extract_string_param(params, "message"),
         true <- same_origin?(conn) do
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
      false -> send_resp(conn, 403, "")
      {:error, _} -> send_resp(conn, 400, "")
    end
  end

  defp extract_string_param(params, key) do
    case params[key] do
      value when is_binary(value) -> {:ok, value}
      nil -> {:error, "missing_#{key}"}
      _ -> {:error, "invalid_#{key}"}
    end
  end

  defp same_origin?(conn) do
    origin = get_req_header(conn, "origin") |> List.first()
    host = HolterWeb.Endpoint.url()

    cond do
      is_nil(origin) -> true
      String.starts_with?(origin, host) -> true
      origin == "http://localhost" -> true
      origin == "http://localhost:4000" -> true
      true -> false
    end
  end
end
