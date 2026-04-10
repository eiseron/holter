defmodule HolterWeb.Components.Header do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a section header with optional subtitle and actions slot.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["h-header", @actions != [] && "h-header-with-actions"]}>
      <div class="h-header-content">
        <h1 class="h-header-title">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="h-header-subtitle">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="h-header-actions">{render_slot(@actions)}</div>
    </header>
    """
  end
end
