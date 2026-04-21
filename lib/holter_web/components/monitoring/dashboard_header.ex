defmodule HolterWeb.Components.Monitoring.DashboardHeader do
  @moduledoc false
  use HolterWeb, :component

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def dashboard_header(assigns) do
    ~H"""
    <header class="dashboard-header-premium">
      <div>
        <h1>{@title}</h1>
        <p :if={@subtitle} class="h-mt-1 h-opacity-60">{@subtitle}</p>
      </div>
      <div :if={@actions != []} class="h-flex h-gap-3">
        {render_slot(@actions)}
      </div>
    </header>
    """
  end
end
