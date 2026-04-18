defmodule HolterWeb.Components.Monitoring.HealthBadge do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders an animated health status badge with a pulse dot.
  When logical_state is :paused, renders a static pause icon with a muted amber style instead.
  """
  attr :status, :atom, required: true
  attr :logical_state, :atom, default: :active

  def health_badge(assigns) do
    ~H"""
    <div class={["h-health-pulse-badge", badge_class(@status, @logical_state)]}>
      <%= if @logical_state == :paused do %>
        <span class="pause-icon"></span>
        <span class="status-label">{gettext("PAUSED")}</span>
      <% else %>
        <span class="pulse-dot"></span>
        <span class="status-label">{@status |> to_string() |> String.upcase()}</span>
      <% end %>
    </div>
    """
  end

  defp badge_class(_status, :paused), do: "h-status-paused"
  defp badge_class(status, _logical_state), do: "h-status-#{status}"
end
