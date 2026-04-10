defmodule HolterWeb.Components.Icon do
  @moduledoc false
  use HolterWeb, :component

  attr :name, :string, required: true
  attr :class, :any, default: "h-icon-size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"h-js-transition h-js-ease-out h-js-duration-300",
         "h-js-opacity-0 h-js-translate-y-4 h-js-scale-95",
         "h-js-opacity-100 h-js-translate-y-0 h-js-scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"h-js-transition h-js-ease-in h-js-duration-200",
         "h-js-opacity-100 h-js-translate-y-0 h-js-scale-100",
         "h-js-opacity-0 h-js-translate-y-4 h-js-scale-95"}
    )
  end
end
