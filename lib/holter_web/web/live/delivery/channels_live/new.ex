defmodule HolterWeb.Web.Delivery.ChannelsLive.New do
  use HolterWeb, :workspace_live_view

  alias Holter.Delivery
  alias Holter.Delivery.Profiles
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} -> mount_for_workspace(socket, workspace)
      {:error, :not_found} -> {:ok, redirect_workspace_not_found(socket)}
    end
  end

  defp mount_for_workspace(socket, workspace) do
    channel_max = Profiles.get_for_workspace!(workspace.id).max_channels

    if Delivery.count_channels(workspace.id) >= channel_max do
      {:ok, redirect_channel_quota_reached(socket, workspace, channel_max)}
    else
      {:ok,
       socket
       |> assign(:workspace, workspace)
       |> assign(:page_title, gettext("New Channel"))}
    end
  end

  defp redirect_workspace_not_found(socket) do
    socket
    |> put_flash(:error, gettext("Workspace not found"))
    |> push_navigate(to: "/")
  end

  defp redirect_channel_quota_reached(socket, workspace, channel_max) do
    socket
    |> put_flash(
      :error,
      gettext("Channel limit reached for this workspace (max: %{max})", max: channel_max)
    )
    |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")
  end
end
