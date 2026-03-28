defmodule HolterWeb.CoreComponents.Button do
  @moduledoc """
  Core Button components with Sentinel Ethos (border-radius: 0).
  """
  use Phoenix.Component
  use Phoenix.VerifiedRoutes,
    endpoint: HolterWeb.Endpoint,
    router: HolterWeb.Router,
    statics: HolterWeb.static_paths()


  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary secondary danger ghost), default: "primary"
  attr :size, :string, values: ~w(sm md lg), default: "md"
  slot :inner_block, required: true

  def button(assigns) do
    variants = %{
      "primary" => "h-btn-primary",
      "secondary" => "h-btn-secondary",
      "danger" => "h-btn-danger",
      "ghost" => "h-btn-ghost"
    }

    sizes = %{
      "sm" => "h-btn-sm",
      "md" => "",
      "lg" => "h-btn-lg"
    }

    classes = [
      "h-btn",
      Map.get(variants, assigns.variant),
      Map.get(sizes, assigns.size),
      assigns.class
    ]

    assigns = assign(assigns, :classes, classes)

    if assigns.rest[:href] || assigns.rest[:navigate] || assigns.rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end
end
