defmodule HolterWeb.Components.Monitoring.IncidentGanttChart do
  @moduledoc false
  use HolterWeb, :component

  @bar_area_height 160
  @bar_height 16
  @lane_count 3

  attr :monitor_id, :string, required: true
  attr :gantt_data, :map, default: %{bars: [], x_labels: [], has_incidents: false}

  def incident_gantt_chart(assigns) do
    ~H"""
    <figure
      :if={@gantt_data.has_incidents}
      class="incident-gantt-container"
      id={"incident-gantt-#{@monitor_id}"}
      aria-label={gettext("Incident timeline")}
    >
      <svg
        class="incident-gantt-svg"
        viewBox="0 0 800 210"
        preserveAspectRatio="none"
        aria-hidden="true"
      >
        <%= for sep <- lane_separators() do %>
          <line x1="40" y1={sep} x2="760" y2={sep} class="gantt-lane-separator" />
        <% end %>

        <%= for {label, y} <- lane_labels() do %>
          <text
            x="2"
            y={y}
            dominant-baseline="middle"
            class="chart-scale-label"
          >
            {label}
          </text>
        <% end %>

        <%= for bar <- @gantt_data.bars do %>
          <rect
            x={bar.x}
            y={lane_y(bar.lane)}
            width={bar.width}
            height={bar_height()}
            fill={bar.fill}
            opacity="0.8"
            class="gantt-bar"
          />
          <line
            :if={bar.open?}
            x1={bar.x + bar.width}
            y1={lane_y(bar.lane)}
            x2={bar.x + bar.width}
            y2={lane_y(bar.lane) + bar_height()}
            class="gantt-bar-open-edge"
          />
        <% end %>

        <%= for lbl <- @gantt_data.x_labels do %>
          <text
            x={lbl.x}
            y="178"
            text-anchor="middle"
            transform={"rotate(-45, #{lbl.x}, 178)"}
            class="metrics-date-label"
          >
            {lbl.label}
          </text>
        <% end %>
      </svg>

      <figcaption>
        <ul class="chart-legend">
          <li class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-down)"></span>
            {gettext("Downtime")}
          </li>
          <li class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-compromised)"></span>
            {gettext("Defacement")}
          </li>
          <li class="chart-legend-item">
            <span class="chart-legend-dot" style="background: var(--color-status-degraded)"></span>
            {gettext("SSL Expiry")}
          </li>
          <li class="chart-legend-item">
            <span class="chart-legend-dash" style="border-top: 2px dashed currentColor; opacity: 0.6">
            </span>
            {gettext("Open")}
          </li>
        </ul>
      </figcaption>
    </figure>
    """
  end

  defp bar_height, do: @bar_height

  defp lane_y(lane) do
    lane_height = @bar_area_height / @lane_count
    Float.round(lane_height * lane + (lane_height - @bar_height) / 2, 1)
  end

  defp lane_separators do
    lane_height = @bar_area_height / @lane_count

    Enum.map(0..@lane_count, fn i ->
      Float.round(i * lane_height, 1)
    end)
  end

  defp lane_labels do
    lane_height = @bar_area_height / @lane_count

    [
      {"Down.", Float.round(lane_height * 0.5, 1)},
      {"Defac.", Float.round(lane_height * 1.5, 1)},
      {"SSL", Float.round(lane_height * 2.5, 1)}
    ]
  end
end
