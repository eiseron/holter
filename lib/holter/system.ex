defmodule Holter.System do
  @moduledoc """
  The System context. Owns the cross-workspace backoffice — admins,
  audit log, and feature flags. Everything here is global: no
  `workspace_id`, no RLS. Access is gated at the application layer
  (`HolterWeb.Hooks.AdminAuthHook` + Bodyguard policies).
  """

  alias Holter.System.{Admins, AuditLogs, FeatureFlags, Users}

  defdelegate admin?(user), to: Admins
  defdelegate get_admin_by_user_id(user_id), to: Admins, as: :get_by_user_id
  defdelegate list_admins(), to: Admins
  defdelegate promote_user(target, actor_admin), to: Admins
  defdelegate demote_admin(admin, actor_admin), to: Admins
  defdelegate bootstrap_promote!(target), to: Admins

  defdelegate list_audit_logs(filters \\ []), to: AuditLogs
  defdelegate log_audit!(params), to: AuditLogs, as: :log!

  defdelegate list_users(params \\ %{}), to: Users
  defdelegate get_user_with_associations!(id), to: Users, as: :get_with_associations!

  defdelegate list_feature_flags(), to: FeatureFlags, as: :list_flags
  defdelegate get_feature_flag!(name), to: FeatureFlags, as: :get_flag!
  defdelegate create_feature_flag(attrs, actor_admin), to: FeatureFlags, as: :create_flag
  defdelegate feature_enabled?(name, subject), to: FeatureFlags, as: :enabled?

  defdelegate set_feature_flag_enabled(flag, enabled, actor_admin),
    to: FeatureFlags,
    as: :set_enabled
end
