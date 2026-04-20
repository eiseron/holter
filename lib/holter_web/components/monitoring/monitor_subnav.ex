defmodule HolterWeb.Components.Monitoring.MonitorSubnav do
  @moduledoc false
  use HolterWeb, :component

  attr :monitor_id, :string, required: true
  attr :current_page, :atom, required: true
  attr :workspace_slug, :string, required: true

  def monitor_subnav(assigns) do
    ~H"""
    <nav class="h-page-nav">
      <.link
        navigate={~p"/workspaces/#{@workspace_slug}/dashboard"}
        class="h-nav-link"
      >
        {gettext("Dashboard")}
      </.link>
      <.link
        :if={@current_page != :show}
        navigate={~p"/monitoring/monitor/#{@monitor_id}"}
        class="h-nav-link"
      >
        {gettext("Monitor Details")}
      </.link>
      <.link
        :if={@current_page != :daily_metrics}
        navigate={~p"/monitoring/monitor/#{@monitor_id}/daily_metrics"}
        class="h-nav-link"
      >
        {gettext("Daily Metrics")}
      </.link>
      <.link
        :if={@current_page != :logs}
        navigate={~p"/monitoring/monitor/#{@monitor_id}/logs"}
        class="h-nav-link"
      >
        {gettext("Technical Logs")}
      </.link>
      <.link
        :if={@current_page != :incidents}
        navigate={~p"/monitoring/monitor/#{@monitor_id}/incidents"}
        class="h-nav-link"
      >
        {gettext("Incidents")}
      </.link>
    </nav>
    """
  end
end
