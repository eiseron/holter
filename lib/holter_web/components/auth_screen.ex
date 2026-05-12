defmodule HolterWeb.Components.AuthScreen do
  @moduledoc false
  use HolterWeb, :component

  attr :title, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true
  slot :footer

  def auth_screen(assigns) do
    ~H"""
    <section class={["h-auth-screen", @class]} {@rest}>
      <div class="h-auth-screen-card">
        <img src={~p"/images/holter.svg"} alt="Holter" class="h-auth-screen-logo" />
        <h1 :if={@title} class="h-auth-screen-title">{@title}</h1>
        {render_slot(@inner_block)}
      </div>
      <div :if={@footer != []} class="h-auth-screen-footer">
        {render_slot(@footer)}
      </div>
    </section>
    """
  end
end
