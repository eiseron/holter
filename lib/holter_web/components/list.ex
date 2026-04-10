defmodule HolterWeb.Components.List do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a data list.

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
    <ul class="h-list">
      <li :for={item <- @item} class="h-list-row">
        <div class="h-list-col-grow">
          <div class="h-list-title">{item.title}</div>
          <div class="h-list-content">{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end
end
