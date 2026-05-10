defmodule HolterWeb.Components.EmptyState do
  @moduledoc false
  use HolterWeb, :component

  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :variant, :string, default: "default", values: ~w(default boxed)
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon
  slot :actions
  slot :inner_block

  def empty_state(assigns) do
    ~H"""
    <section
      class={["h-empty-state", "h-empty-state-#{@variant}", @class]}
      role="status"
      {@rest}
    >
      <div :if={@icon != []} class="h-empty-state-icon" aria-hidden="true">
        {render_slot(@icon)}
      </div>
      <h2 :if={@title} class="h-empty-state-title">{@title}</h2>
      <p :if={@description} class="h-empty-state-description">{@description}</p>
      <div :if={@actions != []} class="h-empty-state-actions">
        {render_slot(@actions)}
      </div>
      <%= if is_nil(@title) and is_nil(@description) do %>
        {render_slot(@inner_block)}
      <% end %>
    </section>
    """
  end
end
