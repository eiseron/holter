defmodule HolterWeb.Web.Monitoring.MonitorLive.Index do
  use HolterWeb, :monitoring_live_view

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
         |> assign(:page_title, gettext("Dashboard"))
         |> fetch_monitors()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    {:noreply, fetch_monitors(socket)}
  end

  defp fetch_monitors(socket) do
    workspace = socket.assigns.workspace
    monitors = Monitoring.list_monitors_with_sparklines(workspace.id)
    active_count = Enum.count(monitors, &(&1.logical_state != :archived))

    socket
    |> assign(:monitors, monitors)
    |> assign(:at_quota, active_count >= workspace.max_monitors)
  end
end
