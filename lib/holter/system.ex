defmodule Holter.System do
  @moduledoc """
  The System context. Owns the cross-workspace backoffice — admins,
  audit log, and (in future MRs) feature flags. Everything here is
  global: no `workspace_id`, no RLS. Access is gated at the application
  layer (`HolterWeb.Hooks.AdminAuthHook` + Bodyguard policies).
  """

  alias Holter.System.{Admins, AuditLogs, Users}

  defdelegate admin?(user), to: Admins
  defdelegate list_admins(), to: Admins
  defdelegate promote_user(target, actor_admin), to: Admins
  defdelegate demote_admin(admin, actor_admin), to: Admins
  defdelegate bootstrap_promote!(target), to: Admins

  defdelegate list_audit_logs(filters \\ []), to: AuditLogs
  defdelegate log_audit!(params), to: AuditLogs, as: :log!

  defdelegate list_users(params \\ %{}), to: Users
  defdelegate get_user_with_associations!(id), to: Users, as: :get_with_associations!
end
