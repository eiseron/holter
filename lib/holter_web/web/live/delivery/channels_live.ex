defmodule HolterWeb.Web.Delivery.ChannelsLive do
  use HolterWeb, :workspace_live_view

  import HolterWeb.Components.Monitoring.DashboardHeader

  alias Holter.Delivery
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, gettext("Notification Channels"))
         |> assign(:channels, Delivery.list_channels(workspace.id))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end
end
