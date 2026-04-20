defmodule HolterWeb.Components.WorkspaceSidebarLive do
  @moduledoc false
  use HolterWeb, :live_component

  alias Holter.Delivery
  alias Holter.Monitoring

  @impl true
  def update(%{workspace: workspace, current_view: current_view}, socket) do
    monitor_count = Monitoring.count_monitors(workspace.id)
    channel_count = Delivery.count_channels(workspace.id)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:current_view, current_view)
     |> assign(:monitor_count, monitor_count)
     |> assign(:channel_count, channel_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <nav class="h-workspace-sidebar">
      <div class="h-sidebar-brand">
        <span class="h-sidebar-workspace-name">{@workspace.name}</span>
      </div>

      <ul class="h-sidebar-nav">
        <li>
          <.link
            navigate={~p"/workspaces/#{@workspace.slug}/monitors"}
            class={[
              "h-sidebar-link",
              active?(@current_view, monitors_views()) && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Monitors")}</span>
            <span class="h-sidebar-badge">{@monitor_count}</span>
          </.link>
        </li>
        <li>
          <.link
            navigate={~p"/workspaces/#{@workspace.slug}/channels"}
            class={[
              "h-sidebar-link",
              active?(@current_view, channels_views()) && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Channels")}</span>
            <span class="h-sidebar-badge">{@channel_count}</span>
          </.link>
        </li>
      </ul>
    </nav>
    """
  end

  defp active?(current_view, views), do: current_view in views

  defp monitors_views do
    [
      HolterWeb.Web.WorkspaceDashboard.MonitorsLive,
      HolterWeb.Web.Monitoring.MonitorLive.New,
      HolterWeb.Web.Monitoring.MonitorLive.Show,
      HolterWeb.Web.Monitoring.MonitorLive.Logs,
      HolterWeb.Web.Monitoring.MonitorLive.Incidents,
      HolterWeb.Web.Monitoring.MonitorLive.DailyMetrics,
      HolterWeb.Web.Monitoring.MonitorLive.LogDetail,
      HolterWeb.Web.Monitoring.MonitorLive.IncidentDetail
    ]
  end

  defp channels_views do
    [
      HolterWeb.Web.WorkspaceDashboard.ChannelsLive,
      HolterWeb.Web.Delivery.NotificationChannelLive.New,
      HolterWeb.Web.Delivery.NotificationChannelLive.Show
    ]
  end
end
