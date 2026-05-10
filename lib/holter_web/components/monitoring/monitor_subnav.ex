defmodule HolterWeb.Components.Monitoring.MonitorSubnav do
  @moduledoc false
  use HolterWeb, :component

  attr :monitor_id, :string, required: true
  attr :current_page, :atom, required: true

  def monitor_subnav(assigns) do
    ~H"""
    <nav class="h-page-nav">
      <.link
        navigate={~p"/monitoring/monitor/#{@monitor_id}"}
        class="h-nav-link"
        aria-current={@current_page == :show && "page"}
      >
        {gettext("Monitor Details")}
      </.link>
      <.link
        navigate={~p"/monitoring/monitor/#{@monitor_id}/daily_metrics"}
        class="h-nav-link"
        aria-current={@current_page == :daily_metrics && "page"}
      >
        {gettext("Daily Metrics")}
      </.link>
      <.link
        navigate={~p"/monitoring/monitor/#{@monitor_id}/logs"}
        class="h-nav-link"
        aria-current={@current_page == :logs && "page"}
      >
        {gettext("Technical Logs")}
      </.link>
      <.link
        navigate={~p"/monitoring/monitor/#{@monitor_id}/incidents"}
        class="h-nav-link"
        aria-current={@current_page == :incidents && "page"}
      >
        {gettext("Incidents")}
      </.link>
    </nav>
    """
  end
end
