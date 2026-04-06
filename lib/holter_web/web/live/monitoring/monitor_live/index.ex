defmodule HolterWeb.Web.Monitoring.MonitorLive.Index do
  use HolterWeb, :live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitors")
        end

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:log_offset, 0)
         |> fetch_monitors()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("prev_history", _params, socket) do
    new_offset = socket.assigns.log_offset + 30
    {:noreply, socket |> assign(:log_offset, new_offset) |> fetch_monitors()}
  end

  @impl true
  def handle_event("next_history", _params, socket) do
    new_offset = max(0, socket.assigns.log_offset - 30)
    {:noreply, socket |> assign(:log_offset, new_offset) |> fetch_monitors()}
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    {:noreply, fetch_monitors(socket)}
  end

  defp fetch_monitors(socket) do
    monitors =
      Monitoring.list_monitors_with_sparklines(
        socket.assigns.workspace.id,
        socket.assigns.log_offset
      )

    assign(socket, :monitors, monitors)
  end
end
