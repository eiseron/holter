defmodule HolterWeb.Components.Monitoring.DailyMetricsSection do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Header
  import HolterWeb.Components.Table

  alias Holter.Monitoring.DailyMetric

  @doc """
  Renders the daily uptime history section with a metrics table.
  """
  attr :metrics, :list, required: true
  attr :logs_url, :string, required: true

  def daily_metrics_section(assigns) do
    ~H"""
    <section class="h-section">
      <.header>
        {gettext("Daily Uptime History")}
        <:actions>
          <.link navigate={@logs_url} class="h-btn h-btn-soft">
            {gettext("View Technical Logs")}
          </.link>
        </:actions>
      </.header>

      <div :if={Enum.empty?(@metrics)} class="h-empty-state">
        <p>{gettext("No history recorded yet. Metrics are aggregated daily at midnight.")}</p>
      </div>

      <.table :if={not Enum.empty?(@metrics)} id="metrics-table" rows={@metrics}>
        <:col :let={metric} label={gettext("Date")}>
          {Calendar.strftime(metric.date, "%Y-%m-%d")}
        </:col>
        <:col :let={metric} label={gettext("Uptime (%)")}>
          <span class={
            if DailyMetric.uptime_healthy?(metric),
              do: "h-text-success",
              else: "h-text-error"
          }>
            {metric.uptime_percent}%
          </span>
        </:col>
        <:col :let={metric} label={gettext("Avg Latency")}>{metric.avg_latency_ms}ms</:col>
        <:col :let={metric} label={gettext("Downtime")}>
          {metric.total_downtime_minutes} {gettext("min")}
        </:col>
      </.table>
    </section>
    """
  end
end
