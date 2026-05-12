defmodule HolterWeb.Web.Admin.UsersLive.Show do
  @moduledoc """
  Admin detail page for a single user — read-only consolidation of
  identity attributes, workspace memberships, and recent audit log
  entries scoped to the user. Cross-workspace admin-only actions on
  the user (impersonation, ban, plan grant) post to dedicated
  controllers from this page when enabled.
  """

  use HolterWeb, :admin_live_view

  alias Holter.System

  def status_label(:pending_verification), do: gettext("Pending verification")
  def status_label(:active), do: gettext("Active")
  def status_label(:pending_billing), do: gettext("Pending billing")
  def status_label(:banned), do: gettext("Banned")
  def status_label(other), do: to_string(other)

  def role_label(:owner), do: gettext("Owner")
  def role_label(:admin), do: gettext("Admin")
  def role_label(:member), do: gettext("Member")
  def role_label(other), do: to_string(other)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    %{user: user, memberships: memberships, audit_log: audit_log} =
      System.get_user_with_associations!(id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Admin · %{email}", email: user.email))
     |> assign(:user, user)
     |> assign(:memberships, memberships)
     |> assign(:audit_log, audit_log)}
  end
end
