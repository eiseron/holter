defmodule HolterWeb.CoreComponents.Badge do
  @moduledoc """
  Core Badge components for Status Indicators (h-badge).
  """
  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext

  @doc """
  Renders a high-contrast status badge.

  ## Examples

      <.badge kind={:active}>Auditing</.badge>
      <.badge kind={:failed}>Down</.badge>
  """
  attr :kind, :atom,
    values: [:active, :up, :down, :failed, :inactive, :paused, :unknown],
    default: :active

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    base_class = "h-badge"

    variant_class =
      case assigns.kind do
        :active -> "h-badge-active"
        :up -> "h-badge-up"
        :down -> "h-badge-down"
        :failed -> "h-badge-failed"
        :inactive -> "h-badge-inactive"
        :paused -> "h-badge-paused"
        _ -> "h-badge-unknown"
      end

    assigns =
      assigns
      |> assign(:base_class, base_class)
      |> assign(:variant_class, variant_class)

    ~H"""
    <span class={[@base_class, @variant_class, @class]}>
      <span :if={@kind in [:active, :up]} class="h-badge-dot" />
      {render_slot(@inner_block)}
    </span>
    """
  end
end
