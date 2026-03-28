defmodule HolterWeb.CoreComponents.List do
  @moduledoc """
  Core List components with Sentinel Ethos (h-list).
  """
  use Phoenix.Component

  @doc """
  Renders a high-precision data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-item">
        <div class="flex flex-col flex-1">
          <div class="list-item-label uppercase text-[0.6875rem] font-semibold text-secondary tracking-widest leading-none mb-1">
            {item.title}
          </div>
          <div class="text-sm font-medium text-primary">{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end
end
