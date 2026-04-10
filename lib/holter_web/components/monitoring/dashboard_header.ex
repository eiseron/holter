defmodule HolterWeb.Components.Monitoring.DashboardHeader do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders the monitoring dashboard page header with a "New Monitor" action button.
  """
  attr :new_monitor_url, :string, required: true

  def dashboard_header(assigns) do
    ~H"""
    <header class="dashboard-header-premium">
      <div>
        <h1>{gettext("Dashboard")}</h1>
        <p class="h-mt-1 h-opacity-60">{gettext("Real-time Overview")}</p>
      </div>
      <div class="h-flex h-gap-3">
        <.link navigate={@new_monitor_url} class="h-btn h-btn-primary">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M12 5v14M5 12h14" />
          </svg>
          {gettext("New Monitor")}
        </.link>
      </div>
    </header>
    """
  end
end
