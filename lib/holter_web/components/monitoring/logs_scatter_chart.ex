defmodule HolterWeb.Components.Monitoring.LogsScatterChart do
  @moduledoc false
  use HolterWeb, :component

  @svg_width 800
  @y_top 10
  @y_bottom 140
  @latency_cap 5000
  @label_left 40

  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []
  attr :start_date, :string, default: nil
  attr :end_date, :string, default: nil

  def logs_scatter_chart(assigns) do
    sorted = Enum.sort_by(assigns.logs, & &1.checked_at, DateTime)
    {min_ts, max_ts} = derive_time_range(sorted, assigns.start_date, assigns.end_date)
    max_latency = derive_max_latency(sorted)

    assigns =
      assigns
      |> assign(:sorted_logs, sorted)
      |> assign(:trend_path, build_trend_path(sorted, min_ts, max_ts, max_latency))
      |> assign(:dots, build_dots(sorted, min_ts, max_ts, max_latency))
      |> assign(:grid_lines, build_grid_lines(max_latency))
      |> assign(:x_label_start, format_ts_label(min_ts))
      |> assign(:x_label_end, format_ts_label(max_ts))

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

          <path d={@trend_path} class="scatter-trend-line" />

          <%= for dot <- @dots do %>
            <circle cx={dot.cx} cy={dot.cy} r="4" fill={dot.fill} class="scatter-dot" />
          <% end %>

          <text x="40" y="158" class="scatter-axis-label">{@x_label_start}</text>
          <text x="798" y="158" text-anchor="end" class="scatter-axis-label">{@x_label_end}</text>
        </svg>
      <% end %>
    </div>
    """
  end

  defp derive_time_range([], start_date, end_date) do
    now = DateTime.utc_now()

    {parse_date_ts(start_date, :start) || DateTime.to_unix(DateTime.add(now, -86_400, :second)),
     parse_date_ts(end_date, :end) || DateTime.to_unix(now)}
  end

  defp derive_time_range(logs, start_date, end_date) do
    first_log_ts = DateTime.to_unix(hd(logs).checked_at)
    last_log_ts = DateTime.to_unix(List.last(logs).checked_at)

    min_ts = parse_date_ts(start_date, :start) || first_log_ts
    max_ts = parse_date_ts(end_date, :end) || last_log_ts

    range = max(max_ts - min_ts, 1)
    {min_ts, min_ts + range}
  end

  defp parse_date_ts(nil, _type), do: nil

  defp parse_date_ts(date_str, type) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         time = if(type == :start, do: ~T[00:00:00], else: ~T[23:59:59]),
         {:ok, dt} <- DateTime.new(date, time, "Etc/UTC") do
      DateTime.to_unix(dt)
    else
      _ -> nil
    end
  end

  defp derive_max_latency([]), do: 0

  defp derive_max_latency(logs) do
    logs
    |> Enum.map(& &1.latency_ms)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
    |> min(@latency_cap)
  end

  defp build_grid_lines(0), do: []

  defp build_grid_lines(max_latency) do
    [1, 2, 3]
    |> Enum.map(fn i ->
      ms = round(max_latency * i / 4)
      %{y: Float.round(normalize_y(ms, max_latency), 1), label: "#{ms}ms"}
    end)
  end

  defp build_trend_path([], _min_ts, _max_ts, _max_latency), do: ""

  defp build_trend_path(logs, min_ts, max_ts, max_latency) do
    "M " <>
      Enum.map_join(logs, " ", fn log ->
        x = map_x(log.checked_at, min_ts, max_ts)
        y = normalize_y(log.latency_ms, max_latency)
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)
  end

  defp build_dots(logs, min_ts, max_ts, max_latency) do
    Enum.map(logs, fn log ->
      %{
        cx: Float.round(map_x(log.checked_at, min_ts, max_ts), 1),
        cy: Float.round(normalize_y(log.latency_ms, max_latency), 1),
        fill: status_color(log.status)
      }
    end)
  end

  defp map_x(dt, min_ts, max_ts) do
    ts = DateTime.to_unix(dt)
    @label_left + (ts - min_ts) / (max_ts - min_ts) * (@svg_width - @label_left) * 1.0
  end

  defp normalize_y(nil, _max), do: @y_bottom * 1.0

  defp normalize_y(latency, 0), do: normalize_y(latency, @latency_cap)

  defp normalize_y(latency, max_latency) do
    clamped = min(latency, max_latency)
    @y_bottom - clamped / max_latency * (@y_bottom - @y_top) * 1.0
  end

  defp format_ts_label(unix_ts) do
    unix_ts
    |> DateTime.from_unix!()
    |> Calendar.strftime("%m-%d %H:%M")
  end

  defp status_color(:up), do: "var(--color-status-up)"
  defp status_color(:down), do: "var(--color-status-down)"
  defp status_color(:degraded), do: "var(--color-status-degraded)"
  defp status_color(:compromised), do: "var(--color-status-compromised)"
  defp status_color(:unknown), do: "var(--color-status-unknown)"
  defp status_color(_), do: "var(--color-status-down)"
end
