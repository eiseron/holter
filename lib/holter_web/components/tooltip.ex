defmodule HolterWeb.Components.Tooltip do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a tooltip.
  """
  attr :text, :string, required: true
  attr :rest, :global
  slot :inner_block

  def tooltip(assigns) do
    ~H"""
    <div class="h-tooltip-wrapper" {@rest}>
      {render_slot(@inner_block)}
      <span class="h-tooltip-text">{@text}</span>
    </div>
    """
  end
end
