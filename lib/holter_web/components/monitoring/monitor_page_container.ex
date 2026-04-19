defmodule HolterWeb.Components.Monitoring.MonitorPageContainer do
  @moduledoc false
  use HolterWeb, :component
  import HolterWeb.Components.Header

  slot :title, required: true
  slot :subtitle
  slot :actions
  slot :inner_block, required: true

  def monitor_page_container(assigns) do
    ~H"""
    <div class="h-monitor-container">
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
