defmodule HolterWeb.Components.Monitoring.MonitorCard do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Monitoring.HealthBadge
  import HolterWeb.Components.Monitoring.Sparkline

  @doc """
  Renders a monitor summary card with status badge, sparkline, and a details link.
  """
  attr :monitor, :map, required: true
  attr :detail_url, :string, required: true

  def monitor_card(assigns) do
    ~H"""
    <div class="monitor-card-premium">
      <header>
        <h3 class="h-font-bold h-text-lg h-truncate" data-role="monitor-url">
          {@monitor.url}
        </h3>
        <div class="h-flex h-justify-between h-items-center h-mt-2">
          <p class="h-text-xs h-opacity-50">
            {@monitor.method |> to_string() |> String.upcase()} • {@monitor.interval_seconds}s
          </p>
          <.health_badge status={@monitor.health_status} logical_state={@monitor.logical_state} />
        </div>
      </header>

      <.sparkline monitor_id={@monitor.id} logs={@monitor.logs} />

      <footer class="h-flex h-justify-between h-items-center h-mt-4">
        <span class="h-text-xs h-font-mono h-opacity-40">
          {@monitor.id |> String.slice(0..7)}
        </span>
        <span
          :if={@monitor.open_incidents_count > 0}
          class="h-badge h-badge-danger h-text-xs"
          data-role="open-incidents-count"
        >
          {gettext("%{count} open", count: @monitor.open_incidents_count)}
        </span>
        <.link
          navigate={@detail_url}
          class="h-text-sky-400 h-text-sm h-font-semibold h-hover-underline"
        >
          {gettext("Details")} →
        </.link>
      </footer>
    </div>
    """
  end
end
