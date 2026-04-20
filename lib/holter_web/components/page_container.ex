defmodule HolterWeb.Components.PageContainer do
  @moduledoc false
  use HolterWeb, :component
  import HolterWeb.Components.Header

  slot :title, required: true
  slot :subtitle
  slot :actions
  slot :inner_block, required: true

  def page_container(assigns) do
    ~H"""
    <div class="h-page-container">
      <.header>
        <div class="h-title-row" data-role="page-title">
          {render_slot(@title)}
        </div>
        <:subtitle>{render_slot(@subtitle)}</:subtitle>
        <:actions>{render_slot(@actions)}</:actions>
      </.header>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
