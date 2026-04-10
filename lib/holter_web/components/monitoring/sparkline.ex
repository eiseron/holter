defmodule HolterWeb.Components.Monitoring.Sparkline do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a latency sparkline SVG chart for a monitor's recent check logs.
  """
  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []

  def sparkline(assigns) do
    data_points = Enum.reverse(assigns.logs)

    assigns =
      assigns
      |> assign(:data_points, data_points)
      |> assign(:path, calculate_path(data_points))

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
          <path d={@path} class="sparkline-line" />

          <%= for {point, index} <- Enum.with_index(@data_points) do %>
            <%= if point.status != :up do %>
              <circle
                cx={index * 10}
                cy={normalize_y(point.latency_ms)}
                r="3"
                fill={status_color(point.status)}
                class="sparkline-error-marker"
              />
            <% end %>
          <% end %>
        </svg>
      <% end %>
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

  defp normalize_y(nil), do: 75

  defp normalize_y(latency) do
    clamped = min(latency, 1000)
    70 - clamped / 1000 * 60
  end

  defp status_color(:down), do: "var(--color-status-down)"
  defp status_color(:compromised), do: "var(--color-status-compromised)"
  defp status_color(:degraded), do: "var(--color-status-degraded)"
  defp status_color(:unknown), do: "var(--color-status-unknown)"
  defp status_color(_), do: "var(--color-status-down)"
end
