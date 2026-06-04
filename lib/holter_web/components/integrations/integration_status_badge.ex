defmodule HolterWeb.Components.Integrations.IntegrationStatusBadge do
  @moduledoc false
  use HolterWeb, :component

  attr :status, :atom, required: true

  def integration_status_badge(assigns) do
    ~H"""
    <span class={["h-badge", badge_class(@status)]} data-role="integration-status">
      {badge_label(@status)}
    </span>
    """
  end

  defp badge_class(:active), do: "h-badge-success"
  defp badge_class(:reauth_required), do: "h-badge-warning"
  defp badge_class(:rate_limited), do: "h-badge-warning"
  defp badge_class(:disabled), do: "h-badge-neutral"
  defp badge_class(:provider_down), do: "h-badge-danger"

  defp badge_label(:active), do: gettext("Connected")
  defp badge_label(:reauth_required), do: gettext("Reconnect needed")
  defp badge_label(:rate_limited), do: gettext("Rate limited")
  defp badge_label(:disabled), do: gettext("Disabled")
  defp badge_label(:provider_down), do: gettext("Provider down")
end
