defmodule HolterWeb.CoreComponents.Icon do
  @moduledoc """
  Core Icon component for Holter.
  Uses Heroicons but applies semantic sizing classes (icon-sm, icon-lg, etc).
  """
  use Phoenix.Component

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="icon-sm animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, "icon", @class]} />
    """
  end
end
