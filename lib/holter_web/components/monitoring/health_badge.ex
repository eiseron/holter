defmodule HolterWeb.Components.Monitoring.HealthBadge do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders an animated health status badge with a pulse dot.
  """
  attr :status, :atom, required: true

  def health_badge(assigns) do
    ~H"""
    <div class={["h-health-pulse-badge", "h-status-#{@status}"]}>
      <span class="pulse-dot"></span>
      <span class="status-label">{@status |> to_string() |> String.upcase()}</span>
    </div>
    """
  end
end
