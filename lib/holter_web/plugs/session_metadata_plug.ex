defmodule HolterWeb.Plugs.SessionMetadataPlug do
  @moduledoc """
  Extracts the session ID from headers or cookies and adds it to Logger metadata and Sentry scope.
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    session_id = get_session_id(conn)

    if session_id do
      Logger.metadata(session_id: session_id)
      Sentry.Context.set_tags(%{session_id: session_id})
    end

    conn
  end

  defp get_session_id(conn) do
    case get_req_header(conn, "x-session-id") do
      [id | _] -> id
      [] -> nil
    end
  end
end
