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
         |> fetch_monitors()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    {:noreply, fetch_monitors(socket)}
  end

  defp fetch_monitors(socket) do
    assign(
      socket,
      :monitors,
      Monitoring.list_monitors_with_sparklines(socket.assigns.workspace.id)
    )
  end
end
