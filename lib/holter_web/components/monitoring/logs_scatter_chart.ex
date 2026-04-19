defmodule HolterWeb.Components.Monitoring.LogsScatterChart do
  @moduledoc false
  use HolterWeb, :component
  alias HolterWeb.Components.ChartUtils

  @svg_width 800
  @y_top 10
  @y_bottom 140
  @latency_cap 5000
  @label_left 40

  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []
  attr :start_date, :string, default: nil
  attr :end_date, :string, default: nil
  attr :timezone, :string, default: "Etc/UTC"

  def logs_scatter_chart(assigns) do
    sorted = Enum.sort_by(assigns.logs, & &1.checked_at, DateTime)

    {min_ts, max_ts} =
      derive_time_range(sorted, %{
        start_date: assigns.start_date,
        end_date: assigns.end_date,
        timezone: assigns.timezone
      })

    max_latency = ChartUtils.derive_max_value(sorted, :latency_ms, @latency_cap)
    range_data = %{min_ts: min_ts, max_ts: max_ts, max_latency: max_latency}

    assigns =
      assigns
      |> assign(:sorted_logs, sorted)
      |> assign(:trend_path, build_trend_path(sorted, range_data))
      |> assign(:dots, build_dots(sorted, range_data))
      |> assign(:grid_lines, build_grid_lines(max_latency))
      |> assign(:vertical_grids, build_vertical_grids(min_ts, max_ts))
      |> assign(:x_label_start, format_ts_label(min_ts, assigns.timezone))
      |> assign(:x_label_end, format_ts_label(max_ts, assigns.timezone))

    ~H"""
    <div class="scatter-chart-container" id={"scatter-chart-#{@monitor_id}"}>
      <%= if @sorted_logs == [] do %>
        <svg class="scatter-svg" viewBox="0 0 800 160" preserveAspectRatio="none">
          <line x1="40" y1="80" x2="800" y2="80" class="chart-empty-line" />
        </svg>
        <p class="scatter-no-data">{gettext("No logs match the current filters")}</p>
      <% else %>
        <svg class="scatter-svg" viewBox="0 0 800 160" preserveAspectRatio="none">
          <line x1="40" y1="140" x2="800" y2="140" class="chart-baseline" />

          <%= for grid <- @grid_lines do %>
            <line x1="40" y1={grid.y} x2="800" y2={grid.y} class="chart-grid-line" />
            <text x="2" y={grid.y + 3} dominant-baseline="middle" class="chart-scale-label">
              {grid.label}
            </text>
          <% end %>

          <%= for vg <- @vertical_grids do %>
            <line x1={vg.x} y1="10" x2={vg.x} y2="140" class="chart-grid-line" />
          <% end %>

          <path d={@trend_path} class="scatter-trend-line" />

          <%= for dot <- @dots do %>
            <circle cx={dot.cx} cy={dot.cy} r="4" fill={dot.fill} class="scatter-dot" />
          <% end %>

          <text x="40" y="158" class="scatter-axis-label">{@x_label_start}</text>
          <text x="798" y="158" text-anchor="end" class="scatter-axis-label">{@x_label_end}</text>
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
          <span class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-unknown)"></span>
            {gettext("Unknown")}
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp derive_time_range([], params) do
    now = DateTime.utc_now()

    {parse_date_ts(params.start_date, :start, params.timezone) ||
       DateTime.to_unix(DateTime.add(now, -86_400, :second)),
     parse_date_ts(params.end_date, :end, params.timezone) || DateTime.to_unix(now)}
  end

  defp derive_time_range(logs, params) do
    first_log_ts = DateTime.to_unix(hd(logs).checked_at)
    last_log_ts = DateTime.to_unix(List.last(logs).checked_at)

    min_ts = parse_date_ts(params.start_date, :start, params.timezone) || first_log_ts
    max_ts = parse_date_ts(params.end_date, :end, params.timezone) || last_log_ts

    range = max(max_ts - min_ts, 1)
    {min_ts, min_ts + range}
  end

  defp parse_date_ts(nil, _type, _timezone), do: nil

  defp parse_date_ts(date_str, type, timezone) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         time = if(type == :start, do: ~T[00:00:00], else: ~T[23:59:59]),
         {:ok, local_dt} <- DateTime.new(date, time, timezone),
         {:ok, utc_dt} <- DateTime.shift_zone(local_dt, "Etc/UTC") do
      DateTime.to_unix(utc_dt)
    else
      _ -> nil
    end
  end

  defp build_grid_lines(0), do: []

  defp build_grid_lines(max_latency) do
    middle =
      [1, 2, 3]
      |> Enum.map(fn i ->
        ms = round(max_latency * i / 4)

        %{
          y:
            Float.round(
              ChartUtils.normalize_y(ms, max_latency, {@y_bottom, @y_top, @latency_cap}),
              1
            ),
          label: "#{ms}ms"
        }
      end)

    [%{y: @y_bottom * 1.0, label: "0ms"}] ++
      middle ++ [%{y: @y_top * 1.0, label: "#{max_latency}ms"}]
  end

  defp build_vertical_grids(_min_ts, _max_ts) do
    Enum.map(1..4, fn i ->
      x = @label_left + i / 5.0 * (@svg_width - @label_left)
      %{x: Float.round(x, 1)}
    end)
  end

  defp build_trend_path([], _range_data), do: ""

  defp build_trend_path(logs, range_data) do
    min_ts = range_data.min_ts
    max_ts = range_data.max_ts
    max_latency = range_data.max_latency

    "M " <>
      Enum.map_join(logs, " ", fn log ->
        x = ChartUtils.map_x(log.checked_at, {min_ts, max_ts}, {@label_left, @svg_width})
        y = ChartUtils.normalize_y(log.latency_ms, max_latency, {@y_bottom, @y_top, @latency_cap})
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)
  end

  defp build_dots(logs, range_data) do
    min_ts = range_data.min_ts
    max_ts = range_data.max_ts
    max_latency = range_data.max_latency

    Enum.map(logs, fn log ->
      %{
        cx:
          Float.round(
            ChartUtils.map_x(log.checked_at, {min_ts, max_ts}, {@label_left, @svg_width}),
            1
          ),
        cy:
          Float.round(
            ChartUtils.normalize_y(
              log.latency_ms,
              max_latency,
              {@y_bottom, @y_top, @latency_cap}
            ),
            1
          ),
        fill: status_color(log.status)
      }
    end)
  end

  defp format_ts_label(unix_ts, timezone) do
    utc = DateTime.from_unix!(unix_ts)

    local =
      case DateTime.shift_zone(utc, timezone) do
        {:ok, dt} -> dt
        _ -> utc
      end

    Calendar.strftime(local, "%m-%d %H:%M")
  end

  defp status_color(:up), do: "var(--color-status-up)"
  defp status_color(:down), do: "var(--color-status-down)"
  defp status_color(:degraded), do: "var(--color-status-degraded)"
  defp status_color(:compromised), do: "var(--color-status-compromised)"
  defp status_color(:unknown), do: "var(--color-status-unknown)"
  defp status_color(_), do: "var(--color-status-down)"
end
