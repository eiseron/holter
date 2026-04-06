defmodule HolterWeb.MonitoringComponents do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext

  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []

  def sparkline(assigns) do
    data_points = Enum.reverse(assigns.logs)

    assigns =
      assigns
      |> assign(:data_points, data_points)
      |> assign(:path, calculate_path(data_points))
      |> assign(:area_path, calculate_area_path(data_points))

    ~H"""
    <div class="sparkline-container" id={"sparkline-#{@monitor_id}"}>
      <%= if @data_points == [] do %>
        <svg class="sparkline-svg" viewBox="0 0 300 80" preserveAspectRatio="none">
          <line
            x1="0"
            y1="75"
            x2="300"
            y2="75"
            stroke="rgba(255,255,255,0.08)"
            stroke-width="1"
            stroke-dasharray="4 4"
          />
        </svg>
        <p class="sparkline-no-data">{gettext("No data yet")}</p>
      <% else %>
        <svg class="sparkline-svg" viewBox="0 0 300 80" preserveAspectRatio="none">
          <defs>
            <linearGradient id={"sparkline-gradient-#{@monitor_id}"} x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stop-color="var(--h-pulse-cyan)" stop-opacity="0.3" />
              <stop offset="100%" stop-color="var(--h-pulse-cyan)" stop-opacity="0" />
            </linearGradient>
          </defs>

          <path
            d={@area_path}
            fill={"url(#sparkline-gradient-#{@monitor_id})"}
            class="sparkline-area"
          />
          <path d={@path} class="sparkline-line" />

          <%= for {point, index} <- Enum.with_index(@data_points) do %>
            <%= if point.status != :up do %>
              <circle
                cx={index * 10}
                cy={normalize_y(point.latency_ms)}
                r="3"
                fill={log_status_color(point.status)}
                class="sparkline-error-marker"
              />
            <% end %>
          <% end %>
        </svg>
      <% end %>
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

  defp log_status_color(:down), do: "var(--h-pulse-rose)"
  defp log_status_color(:compromised), do: "#8b5cf6"
  defp log_status_color(:degraded), do: "#f59e0b"
  defp log_status_color(:unknown), do: "#64748b"
  defp log_status_color(_), do: "var(--h-pulse-rose)"
end
