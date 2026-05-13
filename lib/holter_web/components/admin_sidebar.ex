defmodule HolterWeb.Components.AdminSidebar do
  @moduledoc """
  Sidebar shell for the cross-workspace admin panel. Mirrors the
  `WorkspaceSidebarLive` visual treatment (same `.h-sidebar-*` class
  names) but is a plain functional component — admin navigation has no
  per-render DB counts.

  Each link becomes active as its feature MR lands. Pending features
  render as disabled placeholders (`h-sidebar-link--disabled`).
  """

  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext
  use HolterWeb, :verified_routes

  attr :current_user, :map, required: true
  attr :current_view, :atom, required: true

  def admin_sidebar(assigns) do
    ~H"""
    <nav class="h-workspace-sidebar h-admin-sidebar">
      <div class="h-sidebar-brand">
        <span class="h-sidebar-workspace-name">{gettext("Holter — Admin")}</span>
      </div>

      <ul class="h-sidebar-nav">
        <li>
          <.link
            navigate={~p"/admin/users"}
            class={[
              "h-sidebar-link",
              @current_view == HolterWeb.Web.Admin.UsersLive && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Users")}</span>
          </.link>
        </li>
        <li>
          <span class="h-sidebar-link h-sidebar-link--disabled">
            <span class="h-sidebar-link-label">{gettext("Workspaces")}</span>
            <span class="h-sidebar-badge">{gettext("Soon")}</span>
          </span>
        </li>
        <li>
          <.link
            navigate={~p"/admin/feature-flags"}
            class={[
              "h-sidebar-link",
              @current_view == HolterWeb.Web.Admin.FeatureFlagsLive && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Feature flags")}</span>
          </.link>
        </li>
        <li>
          <.link
            navigate={~p"/admin/audit-log"}
            class={[
              "h-sidebar-link",
              @current_view == HolterWeb.Web.Admin.AuditLogLive && "h-sidebar-link--active"
            ]}
          >
            <span class="h-sidebar-link-label">{gettext("Audit log")}</span>
          </.link>
        </li>
      </ul>

      <div class="h-sidebar-footer">
        <.link navigate={~p"/"} class="h-sidebar-link">
          <span class="h-sidebar-link-label">{gettext("Exit admin")}</span>
        </.link>
      </div>
    </nav>
    """
  end
end
