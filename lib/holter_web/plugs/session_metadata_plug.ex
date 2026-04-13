defmodule HolterWeb.Plugs.SessionMetadataPlug do
  @moduledoc """
  Extracts session, route, and environment metadata for Logger and Sentry.
  Supports both UI and API contexts.
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    session_id = get_session_id(conn)
    workspace_id = extract_workspace_id(conn)

    metadata =
      %{
        session_id: session_id,
        workspace_id: workspace_id,
        request_path: conn.request_path,
        request_method: conn.method,
        remote_ip: format_ip(conn.remote_ip)
      }
      |> Map.merge(Holter.Observability.system_versions())
      |> Map.reject(fn {_, v} -> is_nil(v) end)

    Logger.metadata(Map.to_list(metadata))

    if Code.ensure_loaded?(Sentry.Context) do
      Sentry.Context.set_tags_context(metadata)
    end

    conn
  end

  defp get_session_id(conn) do
    case get_req_header(conn, "x-session-id") do
      [id | _] ->
        id

      [] ->
        case conn.private do
          %{plug_session_fetch: :done} -> get_session(conn, "session_id")
          _ -> nil
        end
    end
  end

  defp extract_workspace_id(conn) do
    case conn.params do
      %Plug.Conn.Unfetched{} -> nil
      params -> params["workspace_id"] || extract_from_body(conn)
    end
  end

  defp extract_from_body(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} -> nil
      params -> params["workspace_id"]
    end
  end

  defp format_ip(ip) do
    ip |> :inet.ntoa() |> to_string()
  end
end
