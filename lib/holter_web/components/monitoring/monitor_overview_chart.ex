defmodule HolterWeb.Components.Monitoring.MonitorOverviewChart do
  @moduledoc false
  use HolterWeb, :component

  @svg_width 800
  @area_height 120
  @y_top 10
  @y_bottom 100
  @latency_cap 2000

  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []

  def monitor_overview_chart(assigns) do
    sorted = Enum.sort_by(assigns.logs, & &1.checked_at, DateTime)

    assigns =
      assigns
      |> assign(:sorted_logs, sorted)
      |> assign(:area_path, build_area_path(sorted))
      |> assign(:line_path, build_line_path(sorted))
      |> assign(:ribbon_rects, build_ribbon_rects(sorted))

    ~H"""
    <div class="ovw-chart-container" id={"ovw-chart-#{@monitor_id}"}>
      <%= if @sorted_logs == [] do %>
        <svg class="ovw-area-svg" viewBox="0 0 800 120" preserveAspectRatio="none">
          <line
            x1="0"
            y1="60"
            x2="800"
            y2="60"
            stroke="rgba(255,255,255,0.08)"
            stroke-width="1"
            stroke-dasharray="6 4"
          />
        </svg>
        <p class="ovw-no-data">{gettext("No data for the last 24 hours")}</p>
      <% else %>
        <svg class="ovw-area-svg" viewBox="0 0 800 120" preserveAspectRatio="none">
          <defs>
            <linearGradient id={"ovw-grad-#{@monitor_id}"} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="var(--color-monitor-pulse-primary)" stop-opacity="0.25" />
              <stop offset="100%" stop-color="var(--color-monitor-pulse-primary)" stop-opacity="0.02" />
            </linearGradient>
          </defs>

          <path
            d={@area_path}
            fill={"url(#ovw-grad-#{@monitor_id})"}
            stroke="none"
            class="ovw-area-fill"
          />
          <path d={@line_path} class="ovw-area-line" />
        </svg>

        <svg class="ovw-ribbon-svg" viewBox="0 0 800 20" preserveAspectRatio="none">
          <%= for rect <- @ribbon_rects do %>
            <rect
              x={rect.x}
              y="0"
              width={rect.width}
              height="20"
              fill={rect.fill}
              opacity="0.75"
            />
          <% end %>
        </svg>
      <% end %>
    </div>
    """
  end

  defp build_line_path([]), do: ""

  defp build_line_path(logs) do
    {min_ts, max_ts} = time_range(logs)

    "M " <>
      Enum.map_join(logs, " ", fn log ->
        x = map_x(log.checked_at, min_ts, max_ts)
        y = normalize_y(log.latency_ms)
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)
  end

  defp build_area_path([]), do: ""

  defp build_area_path(logs) do
    {min_ts, max_ts} = time_range(logs)

    points =
      Enum.map(logs, fn log ->
        x = map_x(log.checked_at, min_ts, max_ts)
        y = normalize_y(log.latency_ms)
        {Float.round(x, 1), Float.round(y, 1)}
      end)

    first_x = elem(hd(points), 0)
    last_x = elem(List.last(points), 0)

    coords = Enum.map_join(points, " ", fn {x, y} -> "#{x},#{y}" end)
    "M #{coords} L #{last_x},#{@area_height} L #{first_x},#{@area_height} Z"
  end

  defp build_ribbon_rects([]), do: []

  defp build_ribbon_rects(logs) do
    {min_ts, max_ts} = time_range(logs)
    count = length(logs)

    logs
    |> Enum.with_index()
    |> Enum.map(fn {log, i} ->
      x = map_x(log.checked_at, min_ts, max_ts)

      width =
        if i < count - 1 do
          next = Enum.at(logs, i + 1)
          map_x(next.checked_at, min_ts, max_ts) - x
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

  defp map_x(dt, min_ts, max_ts) do
    ts = DateTime.to_unix(dt)
    (ts - min_ts) / (max_ts - min_ts) * @svg_width * 1.0
  end

  defp normalize_y(nil), do: @y_bottom * 1.0

  defp normalize_y(latency) do
    clamped = min(latency, @latency_cap)
    @y_bottom - clamped / @latency_cap * (@y_bottom - @y_top) * 1.0
  end

  defp status_color(:up), do: "var(--color-status-up-bg)"
  defp status_color(:down), do: "var(--color-status-down-bg)"
  defp status_color(:degraded), do: "var(--color-status-degraded-bg)"
  defp status_color(:compromised), do: "var(--color-status-compromised-bg)"
  defp status_color(:unknown), do: "var(--color-status-unknown-bg)"
  defp status_color(_), do: "var(--color-status-down-bg)"
end
