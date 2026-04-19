defmodule HolterWeb.Components.Monitoring.MonitorOverviewChart do
  @moduledoc false
  use HolterWeb, :component
  alias HolterWeb.Components.ChartUtils

  @svg_width 800
  @y_top 10
  @y_bottom 100
  @latency_cap 2000
  @label_left 40

  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []
  attr :timezone, :string, default: "Etc/UTC"

  def monitor_overview_chart(assigns) do
    sorted = Enum.sort_by(assigns.logs, & &1.checked_at, DateTime)
    max_latency = ChartUtils.derive_max_value(sorted, :latency_ms, @latency_cap)
    max_scale = max(max_latency, 1)

    assigns =
      assigns
      |> assign(:sorted_logs, sorted)
      |> assign(:area_path, build_area_path(sorted, max_scale))
      |> assign(:line_path, build_line_path(sorted, max_scale))
      |> assign(:ribbon_rects, build_ribbon_rects(sorted))
      |> assign(:grid_lines, build_grid_lines(max_scale))
      |> assign(:x_axis_labels, build_x_axis_labels(sorted, assigns[:timezone] || "Etc/UTC"))

    ~H"""
    <div class="ovw-chart-container" id={"ovw-chart-#{@monitor_id}"}>
      <%= if @sorted_logs == [] do %>
        <svg class="ovw-area-svg" viewBox="0 0 800 100" preserveAspectRatio="none">
          <line x1="40" y1="60" x2="800" y2="60" class="chart-empty-line" />
        </svg>
        <p class="ovw-no-data">{gettext("No data for the last 24 hours")}</p>
      <% else %>
        <svg class="ovw-area-svg" viewBox="0 0 800 120" preserveAspectRatio="none">
          <defs>
            <linearGradient id={"ovw-grad-#{@monitor_id}"} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="var(--prim-purple-500)" stop-opacity="0.3" />
              <stop offset="100%" stop-color="var(--prim-purple-500)" stop-opacity="0.03" />
            </linearGradient>
          </defs>

          <%= for grid <- @grid_lines do %>
            <line x1="40" y1={grid.y} x2="800" y2={grid.y} class="chart-grid-line" />
            <text x="2" y={grid.y + 3} dominant-baseline="middle" class="chart-scale-label">
              {grid.label}
            </text>
          <% end %>

          <%= for label <- @x_axis_labels do %>
            <line x1={label.x} y1="10" x2={label.x} y2="100" class="chart-grid-line" />
            <text
              x={label.x}
              y="115"
              text-anchor="middle"
              class="chart-scale-label"
              dominant-baseline="middle"
            >
              {label.label}
            </text>
          <% end %>

          <line x1="40" y1="100" x2="800" y2="100" class="chart-baseline" />

          <path d={@area_path} fill={"url(#ovw-grad-#{@monitor_id})"} />
          <path d={@line_path} class="ovw-area-line" />
        </svg>

        <svg class="ovw-ribbon-svg" viewBox="0 0 800 20" preserveAspectRatio="none">
          <%= for rect <- @ribbon_rects do %>
            <rect x={rect.x} y="0" width={rect.width} height="20" fill={rect.fill} opacity="0.35" />
          <% end %>
        </svg>

        <div class="chart-legend">
          <span class="chart-legend-item">
            <span class="chart-legend-line" style="background: var(--prim-purple-500)"></span>
            {gettext("Latency")}
          </span>
          <span class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-up)"></span>
            {gettext("Up")}
          </span>
          <span class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-down)"></span>
            {gettext("Down")}
          </span>
          <span class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-degraded)"></span>
            {gettext("Degraded")}
          </span>
          <span class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-compromised)"></span>
            {gettext("Compromised")}
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp build_grid_lines(0), do: []

  defp build_grid_lines(max_latency) do
    num_segments = 4
    segment_size = max_latency / num_segments

    for i <- 0..num_segments do
      ms = i * segment_size

      %{
        y:
          Float.round(
            ChartUtils.normalize_y(ms, max_latency, {@y_bottom, @y_top, @latency_cap}),
            1
          ),
        label: "#{round(ms)}ms"
      }
    end
  end

  defp build_line_path([], _max), do: ""

  defp build_line_path(logs, max_latency) do
    {min_ts, max_ts} = time_range(logs)

    "M " <>
      Enum.map_join(logs, " ", fn log ->
        x = ChartUtils.map_x(log.checked_at, {min_ts, max_ts}, {@label_left, @svg_width})

        y =
          ChartUtils.normalize_y(log.latency_ms, max_latency, {@y_bottom, @y_top, @latency_cap})

        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)
  end

  defp build_area_path([], _max), do: ""

  defp build_area_path(logs, max_latency) do
    {min_ts, max_ts} = time_range(logs)

    points =
      Enum.map(logs, fn log ->
        x = ChartUtils.map_x(log.checked_at, {min_ts, max_ts}, {@label_left, @svg_width})

        y =
          ChartUtils.normalize_y(log.latency_ms, max_latency, {@y_bottom, @y_top, @latency_cap})

        {Float.round(x, 1), Float.round(y, 1)}
      end)

    first_x = elem(hd(points), 0)
    last_x = elem(List.last(points), 0)
    coords = Enum.map_join(points, " ", fn {x, y} -> "#{x},#{y}" end)
    "M #{coords} L #{last_x},#{@y_bottom} L #{first_x},#{@y_bottom} Z"
  end

  defp build_ribbon_rects([]), do: []

  defp build_ribbon_rects(logs) do
    {min_ts, max_ts} = time_range(logs)
    count = length(logs)

    logs
    |> Enum.with_index()
    |> Enum.map(fn {log, i} ->
      x = ChartUtils.map_x(log.checked_at, {min_ts, max_ts}, {@label_left, @svg_width})

      width =
        if i < count - 1 do
          next = Enum.at(logs, i + 1)
          ChartUtils.map_x(next.checked_at, {min_ts, max_ts}, {@label_left, @svg_width}) - x
        else
          @svg_width - x
        end

      %{
        x: Float.round(x, 1),
        width: Float.round(max(width, 1.0), 1),
        fill: status_color(log.status)
      }
    end)
  end

  defp time_range(logs) do
    first = hd(logs).checked_at
    last = List.last(logs).checked_at
    min_ts = DateTime.to_unix(first)
    max_ts = DateTime.to_unix(last)
    range = max(max_ts - min_ts, 1)
    {min_ts, min_ts + range}
  end

  defp status_color(:up), do: "var(--color-status-up)"
  defp status_color(:down), do: "var(--color-status-down)"
  defp status_color(:degraded), do: "var(--color-status-degraded)"
  defp status_color(:compromised), do: "var(--color-status-compromised)"
  defp status_color(:unknown), do: "var(--color-status-unknown)"
  defp status_color(_), do: "var(--color-status-down)"

  defp build_x_axis_labels([], _tz), do: []

  defp build_x_axis_labels(logs, tz) do
    {min_ts, max_ts} = time_range(logs)
    duration = max_ts - min_ts

    num_labels = 5
    interval = duration / (num_labels - 1)

    for i <- 0..(num_labels - 1) do
      ts = min_ts + i * interval

      dt =
        round(ts)
        |> DateTime.from_unix!()
        |> HolterWeb.Timezone.shift_or_utc(tz)

      %{
        x: ChartUtils.map_x(dt, {min_ts, max_ts}, {@label_left, @svg_width}),
        label: Calendar.strftime(dt, "%H:%M")
      }
    end
  end
end
