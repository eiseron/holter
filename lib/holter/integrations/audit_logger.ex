defmodule Holter.Integrations.AuditLogger do
  @moduledoc """
  Coordinator — stamps `DateTime.utc_now/0`, delegates to the `Audit`
  transformer to build attribute maps, then persists via the
  context-owned `Holter.Integrations.IntegrationAuditLogs`.
  """

  alias Holter.Integrations.Audit
  alias Holter.Integrations.IntegrationAuditLogs

  def log_connected(actor_id, workspace_id, provider) do
    now = DateTime.utc_now()
    attrs = Audit.build_connected_audit(actor_id, workspace_id, %{provider: provider, now: now})
    IntegrationAuditLogs.log_attrs!(attrs)
  end

  def log_disconnected(actor_id, workspace_id, provider) do
    now = DateTime.utc_now()

    attrs =
      Audit.build_disconnected_audit(actor_id, workspace_id, %{provider: provider, now: now})

    IntegrationAuditLogs.log_attrs!(attrs)
  end

  def log_action_dispatched(workspace_id, provider, event) do
    now = DateTime.utc_now()
    attrs = Audit.build_action_dispatched_audit(workspace_id, provider, %{event: event, now: now})
    IntegrationAuditLogs.log_attrs!(attrs)
  end

  def log_reauth_failed(workspace_id, provider) do
    now = DateTime.utc_now()
    attrs = Audit.build_reauth_failed_audit(workspace_id, provider, %{now: now})
    IntegrationAuditLogs.log_attrs!(attrs)
  end

  def log_rule_created(actor_id, workspace_id, rule) do
    now = DateTime.utc_now()

    attrs =
      Audit.build_rule_created_audit(actor_id, workspace_id, %{rule: rule, now: now})

    IntegrationAuditLogs.log_attrs!(attrs)
  end

  def log_rule_deleted(actor_id, workspace_id, rule) do
    now = DateTime.utc_now()

    attrs =
      Audit.build_rule_deleted_audit(actor_id, workspace_id, %{rule: rule, now: now})

    IntegrationAuditLogs.log_attrs!(attrs)
  end
end
