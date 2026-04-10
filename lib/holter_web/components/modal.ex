defmodule HolterWeb.Components.Modal do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a modal overlay.
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :show, :boolean, default: false
  attr :class, :string, default: "h-modal-content"
  slot :inner_block, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="h-modal-overlay"
      phx-mounted={@show && JS.remove_attribute("hidden")}
      hidden={not @show}
    >
      <div
        id={"#{@id}-content"}
        class={@class}
        phx-click-away={JS.set_attribute({"hidden", ""}, to: "##{@id}")}
        phx-window-keydown={JS.set_attribute({"hidden", ""}, to: "##{@id}")}
        phx-key="escape"
      >
        <div :if={@title} class="h-modal-header">
          <h2>{@title}</h2>
          <button
            type="button"
            class="h-close-btn"
            phx-click={JS.set_attribute({"hidden", ""}, to: "##{@id}")}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>
        <div class="h-modal-body">
          {render_slot(@inner_block)}
        </div>
        <div :if={@footer != []} class="h-modal-footer">
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end
end
