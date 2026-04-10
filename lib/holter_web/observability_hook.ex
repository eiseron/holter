defmodule HolterWeb.ObservabilityHook do
  import Phoenix.LiveView
  require Logger

  def on_mount(:default, _params, _session, socket) do
    session_id = extract_session_id(socket)

    if session_id do
      Logger.metadata(session_id: session_id)
      Sentry.Context.set_tags(%{session_id: session_id})
    end

    {:cont, assign_new(socket, :session_id, fn -> session_id end)}
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
