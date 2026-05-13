defmodule HolterWeb.Components.WorkspaceSidebarLive do
  @moduledoc false
  use HolterWeb, :live_component

  alias Holter.Delivery
  alias Holter.Delivery.Profiles, as: DeliveryProfiles
  alias Holter.Monitoring
  alias Holter.Monitoring.Profiles, as: MonitoringProfiles
  alias Holter.Repo.Tenant

  @impl true
  def update(assigns, socket) do
    %{workspace: workspace, current_view: current_view} = assigns
    current_user = assigns[:current_user]

    {monitor_count, monitor_max, channel_count, channel_max} =
      Tenant.with_workspace!(workspace.id, fn ->
        {
          Monitoring.count_monitors(workspace.id),
          MonitoringProfiles.get_for_workspace!(workspace.id).max_monitors,
          Delivery.count_channels(workspace.id),
          DeliveryProfiles.get_for_workspace!(workspace.id).max_channels
        }
      end)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:current_view, current_view)
     |> assign(:monitor_count, monitor_count)
     |> assign(:monitor_max, monitor_max)
     |> assign(:channel_count, channel_count)
     |> assign(:channel_max, channel_max)
     |> assign(:current_user, current_user)
     |> assign(:current_workspace_membership, assigns[:current_workspace_membership])}
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
            navigate={~p"/monitoring/workspaces/#{@workspace.slug}/monitors"}
            class={[
              "h-sidebar-link",
              active?(@current_view, monitors_views()) && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Monitors")}</span>
            <span class="h-sidebar-badge">{badge_text(@monitor_count, @monitor_max)}</span>
          </.link>
        </li>
        <li>
          <.link
            navigate={~p"/delivery/workspaces/#{@workspace.slug}/channels"}
            class={[
              "h-sidebar-link",
              active?(@current_view, channels_views()) && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Notifications")}</span>
            <span class="h-sidebar-badge">{badge_text(@channel_count, @channel_max)}</span>
          </.link>
        </li>
        <li :if={admin?(@current_workspace_membership)}>
          <.link
            navigate={~p"/identity/workspaces/#{@workspace.slug}"}
            class={[
              "h-sidebar-link",
              active?(@current_view, workspace_settings_views()) && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Settings")}</span>
          </.link>
        </li>
        <li :if={admin?(@current_workspace_membership)}>
          <.link
            navigate={~p"/identity/workspaces/#{@workspace.slug}/api-tokens"}
            class={[
              "h-sidebar-link",
              active?(@current_view, api_tokens_views()) && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("API tokens")}</span>
          </.link>
        </li>
      </ul>

      <div :if={@current_user} class="h-sidebar-footer">
        <.link
          navigate={~p"/identity/user/#{@current_user.id}"}
          class={[
            "h-sidebar-link",
            active?(@current_view, user_settings_views()) && "h-sidebar-link--active"
          ]}
        >
          <span class="h-sidebar-link-label">{gettext("My account")}</span>
        </.link>
      </div>
    </nav>
    """
  end

  defp active?(current_view, views), do: current_view in views

  defp admin?(%{role: role}) when role in [:owner, :admin], do: true
  defp admin?(_), do: false

  defp monitors_views do
    [
      HolterWeb.Web.Monitoring.MonitorsLive,
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
      HolterWeb.Web.Delivery.ChannelsLive,
      HolterWeb.Web.Delivery.ChannelsLive.New,
      HolterWeb.Web.Delivery.WebhookChannelLive.New,
      HolterWeb.Web.Delivery.WebhookChannelLive.Show,
      HolterWeb.Web.Delivery.WebhookChannelLive.Logs,
      HolterWeb.Web.Delivery.EmailChannelLive.New,
      HolterWeb.Web.Delivery.EmailChannelLive.Show,
      HolterWeb.Web.Delivery.EmailChannelLive.Logs
    ]
  end

  defp workspace_settings_views do
    [HolterWeb.Web.Workspaces.ShowLive]
  end

  defp api_tokens_views do
    [HolterWeb.Web.Workspaces.ApiTokensLive]
  end

  defp user_settings_views do
    [HolterWeb.Web.Identity.UserLive.Show]
  end

  defp badge_text(count, max) when count >= max, do: "#{count}/#{max}"
  defp badge_text(count, _max), do: "#{count}"
end
