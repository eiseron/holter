defmodule HolterWeb.MonitoringComponents do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext

  @spec sparkline_navigator(map) :: Phoenix.LiveView.Rendered.t()
  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []

  def sparkline_navigator(assigns) do
    data_points =
      assigns.logs
      |> Enum.reverse()

    assigns =
      assigns
      |> assign(:data_points, data_points)
      |> assign(:path, calculate_path(data_points))
      |> assign(:area_path, calculate_area_path(data_points))

    ~H"""
    <div class="sparkline-container" id={"sparkline-#{@monitor_id}"}>
      <div class="history-controls">
        <button
          class="history-btn"
          phx-click="prev_history"
          phx-value-monitor-id={@monitor_id}
          aria-label={gettext("Previous history")}
        >
          <span class="hero-chevron-left h-icon-size-4"></span>
        </button>
        <button
          class="history-btn"
          phx-click="next_history"
          phx-value-monitor-id={@monitor_id}
          aria-label={gettext("Next history")}
        >
          <span class="hero-chevron-right h-icon-size-4"></span>
        </button>
      </div>

      <svg class="sparkline-svg" viewBox="0 0 300 80" preserveAspectRatio="none">
        <defs>
          <linearGradient id={"sparkline-gradient-#{@monitor_id}"} x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="var(--h-pulse-cyan)" stop-opacity="0.3" />
            <stop offset="100%" stop-color="var(--h-pulse-cyan)" stop-opacity="0" />
          </linearGradient>
        </defs>

        <path d={@area_path} fill={"url(#sparkline-gradient-#{@monitor_id})"} class="sparkline-area" />
        <path d={@path} class="sparkline-line" />

        <%= for {point, index} <- Enum.with_index(@data_points) do %>
          <%= if point.status != :success do %>
            <circle
              cx={index * 10}
              cy={normalize_y(point.latency_ms)}
              r="3"
              fill="var(--h-pulse-rose)"
              class="sparkline-error-marker"
            />
          <% end %>
        <% end %>
      </svg>
    </div>
    """
  end

  attr :status, :atom, required: true

  def health_badge(assigns) do
    ~H"""
    <div class={["h-health-pulse-badge", "h-status-#{@status}"]}>
      <span class="pulse-dot"></span>
      <span class="status-label">{String.upcase(to_string(@status))}</span>
    </div>
    """
  end

  defp calculate_path([]), do: ""

  defp calculate_path(logs) do
    "M " <>
      Enum.map_join(Enum.with_index(logs), " ", fn {log, i} ->
        "#{i * 10},#{normalize_y(log.latency_ms)}"
      end)
  end

  defp calculate_area_path([]), do: ""

  defp calculate_area_path(logs) do
    path = calculate_path(logs)
    last_x = (length(logs) - 1) * 10
    path <> " L #{last_x},80 L 0,80 Z"
  end

  defp normalize_y(nil), do: 75

  defp normalize_y(latency) do
    clamped = min(latency, 1000)
    70 - clamped / 1000 * 60
  end
end
