defmodule HolterWeb.CoreComponents.Card do
  @moduledoc """
  Core Card components for Monitoring Blocks (h-card).
  """
  use Phoenix.Component

  @doc """
  Renders a flat monitoring card with Sentinel Ethos (90-degree corners).

  ## Examples

      <.card>
        <:header title="System Uptime" />
        <div class="metric">99.8%</div>
      </.card>
  """
  attr :class, :any, default: nil
  slot :header do
    attr :title, :string, required: true
    attr :subtitle, :string
  end
  slot :actions
  slot :footer
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["card", @class]}>
      <%= if @header != [] do %>
        <div :for={header <- @header} class="card-header">
          <div>
            <h3 class="card-title">{header.title}</h3>
            <p :if={Map.get(header, :subtitle)} class="card-subtitle">{header[:subtitle]}</p>
          </div>
          <div :if={@actions != []} class="card-actions">
            {render_slot(@actions)}
          </div>
        </div>
      <% end %>
      <div class="card-body">
        {render_slot(@inner_block)}
      </div>
      <div :if={@footer != [] && @header == []} class="card-footer">
        {render_slot(@footer)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a card metric display.
  """
  attr :label, :string, required: true
  slot :inner_block, required: true

  def card_metric(assigns) do
    ~H"""
    <div class="flex flex-col gap-1 mt-2">
      <div class="card-metric">{render_slot(@inner_block)}</div>
      <div class="card-metric-label">{@label}</div>
    </div>
    """
  end
end
