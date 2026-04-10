defmodule HolterWeb.Components.EmptyState do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders an empty state container.

  ## Examples

      <.empty_state>
        <p>No items found.</p>
      </.empty_state>

      <.empty_state class="h-empty-state-dark">
        <p>No monitors found in this workspace.</p>
      </.empty_state>
  """
  attr :class, :string, default: "h-empty-state"
  slot :inner_block, required: true

  def empty_state(assigns) do
    ~H"""
    <div class={@class}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
