defmodule HolterWeb.ObservabilityHook do
  @moduledoc """
  Mount hook for LiveView to inject session and environment metadata.
  """
  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  def on_mount(:default, _params, session, socket) do
    session_id = extract_session_id(socket) || Map.get(session, "session_id")
    workspace_id = Map.get(session, "workspace_id")

    metadata =
      %{
        request_id: extract_request_id(socket),
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

  defp extract_request_id(socket) do
    if connected?(socket) do
      get_connect_info(socket, :x_headers)
      |> Enum.find_value(fn
        {"x-request-id", value} -> value
        _ -> nil
      end)
    else
      nil
    end
  end

  defp extract_session_id(socket) do
    if connected?(socket) do
      case get_connect_params(socket) do
        %{"session_id" => id} -> id
        _ -> nil
      end
    else
      nil
    end
  end
end
