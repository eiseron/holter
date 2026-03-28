defmodule HolterWeb.CoreComponents.Header do
  @moduledoc """
  Core Page Header components with Sentinel Ethos (2px ghost border).
  """
  use Phoenix.Component

  @doc """
  Renders a page header with title, subtitle and actions.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions
  attr :class, :any, default: nil

  def header(assigns) do
    ~H"""
    <header class={["app-header", @actions != [] && "flex items-center justify-between", @class]}>
      <div>
        <h1 class="app-header-wordmark">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-secondary mt-1">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="app-header-end">{render_slot(@actions)}</div>
    </header>
    """
  end
end
