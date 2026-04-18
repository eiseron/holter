defmodule HolterWeb.Components.Monitoring.DailyMetricsChart do
  @moduledoc false
  use HolterWeb, :component

  alias Holter.Monitoring.DailyMetric

  @bar_area_height 160
  @latency_cap 5000
  @label_left 40
  @chart_content_width 720

  @uptime_grid_pcts [0, 25, 50, 75, 100]

  attr :monitor_id, :string, required: true
  attr :metrics, :list, default: []

  def daily_metrics_chart(assigns) do
    sorted = Enum.sort_by(assigns.metrics, & &1.date, Date)
    count = length(sorted)
    slot_width = if count > 0, do: @chart_content_width / count, else: @chart_content_width
    max_latency = derive_max_latency(sorted)

    assigns =
      assigns
      |> assign(:sorted_metrics, sorted)
      |> assign(:bars, build_bars(sorted, slot_width))
      |> assign(:latency_path, build_latency_path(sorted, slot_width, max_latency))
      |> assign(:uptime_grid, build_uptime_grid())
      |> assign(:latency_labels, build_latency_labels(max_latency))

    ~H"""
    <div class="metrics-chart-container" id={"metrics-chart-#{@monitor_id}"}>
      <%= if @sorted_metrics == [] do %>
        <svg class="metrics-svg" viewBox="0 0 800 230" preserveAspectRatio="none">
          <line x1="40" y1="80" x2="760" y2="80" class="chart-empty-line" />
        </svg>
        <p class="metrics-no-data">{gettext("No daily metrics recorded yet")}</p>
      <% else %>
        <svg class="metrics-svg" viewBox="0 0 800 230" preserveAspectRatio="none">
          <line x1="40" y1="160" x2="760" y2="160" class="chart-baseline" />

          <%= for grid <- @uptime_grid do %>
            <line x1="40" y1={grid.y} x2="760" y2={grid.y} class="chart-grid-line" />
            <text x="2" y={grid.y + 3} dominant-baseline="middle" class="chart-scale-label">
              {grid.label}
            </text>
          <% end %>

          <%= for bar <- @bars do %>
            <rect
              x={bar.x}
              y={bar.y}
              width={bar.width}
              height={bar.height}
              fill={bar.fill}
              opacity="0.35"
              class="metrics-bar"
            />
            <text
              x={bar.label_x}
              y="210"
              text-anchor="middle"
              transform={"rotate(-45, #{bar.label_x}, 210)"}
              class="metrics-date-label"
            >
              {bar.label}
            </text>
          <% end %>

          <path d={@latency_path} class="metrics-latency-line" />

          <%= for lbl <- @latency_labels do %>
            <text
              x="764"
              y={lbl.y + 3}
              dominant-baseline="middle"
              class="chart-scale-label"
            >
              {lbl.label}
            </text>
          <% end %>
        </svg>

        <div class="chart-legend">
          <span class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-up)"></span>
            {gettext("Uptime ≥ 99%")}
          </span>
          <span class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-down)"></span>
            {gettext("Uptime < 99%")}
          </span>
          <span class="chart-legend-item">
            <span class="chart-legend-line" style="background: var(--prim-purple-500)"></span>
            {gettext("Avg Latency")}
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp build_uptime_grid do
    Enum.map(@uptime_grid_pcts, fn pct ->
      y = Float.round(@bar_area_height - pct / 100.0 * @bar_area_height, 1)
      %{y: y, label: "#{pct}%"}
    end)
  end

  defp build_latency_labels(0), do: []

  defp build_latency_labels(max_latency) do
    Enum.map(@uptime_grid_pcts, fn pct ->
      y = Float.round(@bar_area_height - pct / 100.0 * @bar_area_height, 1)
      ms = round(max_latency * pct / 100)
      %{y: y, label: "#{ms}ms"}
    end)
  end

  defp build_bars(metrics, slot_width) do
    metrics
    |> Enum.with_index()
    |> Enum.map(fn {metric, i} ->
      uptime = metric.uptime_percent |> Decimal.to_float()
      bar_height = uptime / 100.0 * @bar_area_height * 1.0
      x = @label_left + i * slot_width * 1.0
      bar_width = max(slot_width - 2.0, 1.0)

      %{
        x: Float.round(x + 1, 1),
        y: Float.round(@bar_area_height - bar_height, 1),
        width: Float.round(bar_width, 1),
        height: Float.round(bar_height, 1),
        fill:
          if(DailyMetric.uptime_healthy?(metric),
            do: "var(--color-status-up)",
            else: "var(--color-status-down)"
          ),
        label: Calendar.strftime(metric.date, "%m/%d"),
        label_x: Float.round(x + slot_width / 2, 1)
      }
    end)
  end

  defp build_latency_path([], _slot_width, _max_latency), do: ""

  defp build_latency_path(metrics, slot_width, max_latency) do
    coords =
      metrics
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {metric, i} ->
        x = @label_left + i * slot_width + slot_width / 2
        y = normalize_latency_y(metric.avg_latency_ms, max_latency)
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)

    "M " <> coords
  end

  defp derive_max_latency([]), do: 0

  defp derive_max_latency(metrics) do
    metrics
    |> Enum.map(& &1.avg_latency_ms)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
    |> min(@latency_cap)
  end

  defp normalize_latency_y(nil, _max), do: @bar_area_height * 1.0
  defp normalize_latency_y(_latency, 0), do: @bar_area_height * 1.0

  defp normalize_latency_y(latency, max_latency) do
    clamped = min(latency, max_latency)
    @bar_area_height - clamped / max_latency * @bar_area_height * 1.0
  end
end
