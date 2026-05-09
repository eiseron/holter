defmodule HolterWeb.Components.UserSidebar do
  @moduledoc """
  Sidebar shell for routes scoped to the signed-in user (today: the
  user settings page at `/identity/user/:id`). Mirrors the
  `WorkspaceSidebarLive` shape so the user shell feels continuous with
  the workspace shell — including the "My account" link sitting in the
  footer slot, at the same spot it occupies in the workspace sidebar.

  Reuses the `.h-workspace-sidebar` / `.h-sidebar-*` class names —
  same visual treatment, no shared state requirements that would
  warrant a `live_component`.
  """

  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext
  use HolterWeb, :verified_routes

  attr :current_user, :map, required: true
  attr :memberships, :list, default: []
  attr :current_view, :atom, required: true

  def user_sidebar(assigns) do
    ~H"""
    <nav class="h-workspace-sidebar">
      <div class="h-sidebar-brand">
        <span class="h-sidebar-workspace-name">{@current_user.email}</span>
      </div>

      <ul class="h-sidebar-nav">
        <li :for={membership <- @memberships}>
          <.link
            :if={membership.role in [:owner, :admin]}
            navigate={~p"/workspaces/#{membership.workspace.slug}"}
            class="h-sidebar-link"
          >
            <span class="h-sidebar-link-label">{membership.workspace.name}</span>
            <span class="h-sidebar-badge">{role_label(membership.role)}</span>
          </.link>
          <span
            :if={membership.role not in [:owner, :admin]}
            class="h-sidebar-link h-sidebar-link--disabled"
          >
            <span class="h-sidebar-link-label">{membership.workspace.name}</span>
            <span class="h-sidebar-badge">{role_label(membership.role)}</span>
          </span>
        </li>
      </ul>

      <div class="h-sidebar-footer">
        <.link
          navigate={~p"/identity/user/#{@current_user.id}"}
          class={[
            "h-sidebar-link",
            user_settings_active?(@current_view) && "h-sidebar-link--active"
          ]}
        >
          <span class="h-sidebar-link-label">{gettext("My account")}</span>
        </.link>
      </div>
    </nav>
    """
  end

  defp user_settings_active?(HolterWeb.Web.Identity.UserLive.Show), do: true
  defp user_settings_active?(_), do: false

  defp role_label(:owner), do: gettext("Owner")
  defp role_label(:admin), do: gettext("Admin")
  defp role_label(:member), do: gettext("Member")
end
