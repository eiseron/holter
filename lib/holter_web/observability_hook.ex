defmodule HolterWeb.ObservabilityHook do
  @moduledoc """
  Mount hook for LiveView to inject session and environment metadata.
  """
  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  def on_mount(:default, _params, session, socket) do
    session_id = extract_from_params(socket, "session_id") || Map.get(session, "session_id")
    request_id = extract_from_params(socket, "request_id") || Map.get(session, "request_id")
    workspace_id = Map.get(session, "workspace_id")

    metadata =
      %{
        request_id: request_id,
        session_id: session_id,
        workspace_id: workspace_id,
        context: :live_view,
        view: socket.view |> to_string(),
        user_agent: get_connect_info(socket, :user_agent)
      }
      |> Map.merge(Holter.Observability.system_versions())
      |> Map.reject(fn {_, v} -> is_nil(v) end)

    Logger.metadata(Map.to_list(metadata))

    if Code.ensure_loaded?(Sentry.Context) do
      Sentry.Context.set_tags_context(metadata)
    end

    {:cont, assign_new(socket, :session_id, fn -> session_id end)}
  end

  defp extract_from_params(socket, key) do
    if connected?(socket) do
      case get_connect_params(socket) do
        %{^key => value} -> value
        _ -> nil
      end
    else
      nil
    end
  end
end
