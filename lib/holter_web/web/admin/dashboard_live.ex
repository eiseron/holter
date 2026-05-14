defmodule HolterWeb.Web.Admin.DashboardLive do
  @moduledoc """
  Landing page of the admin panel (`/admin`). MR1 ships the foundation
  only — the page is a placeholder that confirms the auth pipeline
  works end-to-end and that the layout/sidebar render. Real features
  (user listing, impersonation, ban, feature flags, audit log viewer)
  arrive in subsequent MRs.
  """

  use HolterWeb, :admin_live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Admin Panel"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="h-admin-content">
      <header class="h-admin-content-header">
        <h1>{gettext("Admin Panel")}</h1>
        <p class="h-admin-lede">
          {gettext(
            "God Mode foundation. Real admin features land in subsequent MRs — user CRM, impersonation, ban hammer, feature flags, and audit log viewer."
          )}
        </p>
      </header>

      <ul class="h-admin-feature-grid">
        <li class="h-admin-feature-card">
          <h2>
            <.link navigate={~p"/admin/users"}>{gettext("Users")}</.link>
          </h2>
          <p>{gettext("Search, inspect, impersonate, ban.")}</p>
          <.link navigate={~p"/admin/users"} class="h-admin-feature-action">
            {gettext("Open")}
          </.link>
        </li>
        <li class="h-admin-feature-card">
          <h2>
            <.link navigate={~p"/admin/workspaces"}>{gettext("Workspaces")}</.link>
          </h2>
          <p>{gettext("Cross-workspace visibility for support.")}</p>
          <.link navigate={~p"/admin/workspaces"} class="h-admin-feature-action">
            {gettext("Open")}
          </.link>
        </li>
        <li class="h-admin-feature-card">
          <h2>
            <.link navigate={~p"/admin/feature-flags"}>{gettext("Feature flags")}</.link>
          </h2>
          <p>{gettext("Global kill switch, beta overrides, canary rollout.")}</p>
          <.link navigate={~p"/admin/feature-flags"} class="h-admin-feature-action">
            {gettext("Open")}
          </.link>
        </li>
        <li class="h-admin-feature-card">
          <h2>
            <.link navigate={~p"/admin/audit-log"}>{gettext("Audit log")}</.link>
          </h2>
          <p>{gettext("Append-only history of every admin action.")}</p>
          <.link navigate={~p"/admin/audit-log"} class="h-admin-feature-action">
            {gettext("Open")}
          </.link>
        </li>
      </ul>
    </section>
    """
  end
end
