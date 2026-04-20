defmodule HolterWeb.Web.Delivery.NotificationChannelLive.Index do
  use HolterWeb, :live_view

  alias Holter.Delivery
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        channels = Delivery.list_channels(workspace.id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:channels, channels)
         |> assign(:page_title, gettext("Notification Channels"))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Delivery.get_channel(id) do
      {:ok, channel} ->
        {:ok, _} = Delivery.delete_channel(channel)
        channels = Delivery.list_channels(socket.assigns.workspace.id)
        {:noreply, assign(socket, :channels, channels)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Channel not found"))}
    end
  end
end
