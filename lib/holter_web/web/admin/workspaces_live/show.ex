defmodule HolterWeb.Web.Admin.WorkspacesLive.Show do
  @moduledoc """
  Admin detail page for a single workspace — read-only consolidation of
  workspace attributes, members, monitors, and recent admin audit log
  entries scoped to the workspace.
  """

  use HolterWeb, :admin_live_view

  alias Holter.System

  def role_label(:owner), do: gettext("Owner")
  def role_label(:admin), do: gettext("Admin")
  def role_label(:member), do: gettext("Member")

  def user_status_label(:pending_verification), do: gettext("Pending verification")
  def user_status_label(:active), do: gettext("Active")
  def user_status_label(:pending_billing), do: gettext("Pending billing")
  def user_status_label(:banned), do: gettext("Banned")

  def monitor_state_label(:active), do: gettext("Active")
  def monitor_state_label(:paused), do: gettext("Paused")
  def monitor_state_label(:archived), do: gettext("Archived")

  def health_label(:up), do: gettext("Up")
  def health_label(:down), do: gettext("Down")
  def health_label(:degraded), do: gettext("Degraded")
  def health_label(:compromised), do: gettext("Compromised")
  def health_label(:unknown), do: gettext("Unknown")

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    %{
      workspace: workspace,
      monitoring_profile: monitoring_profile,
      delivery_profile: delivery_profile,
      members: members,
      monitors: monitors,
      audit_log: audit_log
    } = System.get_workspace_with_associations!(id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Admin · %{name}", name: workspace.name))
     |> assign(:workspace, workspace)
     |> assign(:monitoring_profile, monitoring_profile)
     |> assign(:delivery_profile, delivery_profile)
     |> assign(:members, members)
     |> assign(:monitors, monitors)
     |> assign(:audit_log, audit_log)}
  end
end
