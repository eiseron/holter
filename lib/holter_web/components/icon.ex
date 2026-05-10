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

  def icon(%{name: "monitor"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class={@class}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <rect x="2" y="3" width="20" height="14" rx="2" />
      <line x1="8" y1="21" x2="16" y2="21" />
      <line x1="12" y1="17" x2="12" y2="21" />
    </svg>
    """
  end

  def icon(%{name: "bell"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class={@class}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
      <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
    </svg>
    """
  end

  def icon(%{name: "chart-bar"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class={@class}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <line x1="3" y1="20" x2="21" y2="20" />
      <rect x="6" y="11" width="3" height="9" />
      <rect x="11" y="7" width="3" height="13" />
      <rect x="16" y="14" width="3" height="6" />
    </svg>
    """
  end

  def icon(%{name: "shield-check"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class={@class}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      <path d="m9 12 2 2 4-4" />
    </svg>
    """
  end

  def icon(%{name: "plus"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class={@class}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M12 5v14M5 12h14" />
    </svg>
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
