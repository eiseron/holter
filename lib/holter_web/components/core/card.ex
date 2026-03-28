defmodule HolterWeb.CoreComponents.Card do
  @moduledoc """
  Core Card components for Monitoring Blocks (h-card).
  """
  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext

  @doc """
  Renders a flat monitoring card with Sentinel Ethos (90-degree corners).

  ## Examples

      <.card>
        <:header title="System Uptime" />
        <div class="h-card-metric">99.8%</div>
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
    <article class={["h-card", @class]}>
      <%= if @header != [] do %>
        <header :for={header <- @header} class="h-card-header">
          <div>
            <h3 class="h-card-title">{header.title}</h3>
            <p :if={Map.get(header, :subtitle)} class="h-card-subtitle">{header[:subtitle]}</p>
          </div>
          <div :if={@actions != []} class="h-card-actions">
            {render_slot(@actions)}
          </div>
        </header>
      <% end %>
      <div class="h-card-body">
        {render_slot(@inner_block)}
      </div>
      <footer :if={@footer != [] && @header == []} class="h-card-footer">
        {render_slot(@footer)}
      </footer>
    </article>
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
      <div class="h-card-metric">{render_slot(@inner_block)}</div>
      <div class="h-card-metric-label">{@label}</div>
    </div>
    """
  end
end
