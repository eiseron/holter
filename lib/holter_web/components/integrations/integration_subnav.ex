defmodule HolterWeb.Components.Integrations.IntegrationSubnav do
  @moduledoc false
  use HolterWeb, :component

  attr :integration_id, :string, required: true
  attr :current_page, :atom, required: true

  def integration_subnav(assigns) do
    ~H"""
    <nav class="h-page-nav" aria-label={gettext("Integration sections")}>
      <.link
        navigate={~p"/integrations/#{@integration_id}"}
        class="h-nav-link"
        aria-current={@current_page == :rules && "page"}
        data-role="tab-rules"
      >
        {gettext("Rules")}
      </.link>
      <.link
        navigate={~p"/integrations/#{@integration_id}/logs"}
        class="h-nav-link"
        aria-current={@current_page == :logs && "page"}
        data-role="tab-logs"
      >
        {gettext("Logs")}
      </.link>
    </nav>
    """
  end
end
