defmodule HolterWeb.Components.BackLink do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a back navigation link with a left arrow icon.
  """
  attr :navigate, :string, required: true

  def back_link(assigns) do
    ~H"""
    <.link navigate={@navigate} class="h-btn-back">
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
        <path d="M19 12H5M12 5l-7 7 7 7" />
      </svg>
    </.link>
    """
  end
end
