defmodule HolterWeb.CoreComponents.Helpers do
  @moduledoc """
  Shared JS helpers and utilities for Core Components.
  """
  alias Phoenix.LiveView.JS

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 80,
      transition:
        {"transition-opacity duration-80 linear",
         "opacity-0",
         "opacity-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 80,
      transition:
        {"transition-opacity duration-80 linear",
         "opacity-100",
         "opacity-0"}
    )
  end
end
