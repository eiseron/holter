defmodule HolterWeb.Monitoring.MonitorLive.Index do
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
         |> assign(:monitors, Monitoring.list_monitors_by_workspace(workspace.id))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    {:noreply,
     assign(socket, monitors: Monitoring.list_monitors_by_workspace(socket.assigns.workspace.id))}
  end
end
