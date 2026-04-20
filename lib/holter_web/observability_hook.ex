defmodule HolterWeb.ObservabilityHook do
  @moduledoc """
  Mount hook for LiveView to inject session and environment metadata.
  """
  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  @max_timezone_length 64

  def on_mount(:default, _params, session, socket) do
    session_id = extract_from_params(socket, "session_id") || Map.get(session, "session_id")
    request_id = extract_from_params(socket, "request_id") || Map.get(session, "request_id")
    workspace_id = Map.get(session, "workspace_id")
    timezone = sanitize_timezone(extract_from_params(socket, "timezone"))

    metadata =
      %{
        request_id: request_id,
        session_id: session_id,
        workspace_id: workspace_id,
        context: :live_view,
        view: socket.view |> to_string(),
        user_agent: get_connect_info(socket, :user_agent)
      }
      |> Map.reject(fn {_, v} -> is_nil(v) end)

    Logger.metadata(Map.to_list(metadata))

    if Code.ensure_loaded?(Sentry.Context) do
      Sentry.Context.set_tags_context(metadata)
    end

    socket =
      socket
      |> assign_new(:session_id, fn -> session_id end)
      |> assign_new(:timezone, fn -> timezone end)

    {:cont, socket}
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

  defp sanitize_timezone(raw) when is_binary(raw) and byte_size(raw) <= @max_timezone_length do
    if HolterWeb.Timezone.valid_timezone?(raw), do: raw, else: "Etc/UTC"
  end

  defp sanitize_timezone(_), do: "Etc/UTC"
end
