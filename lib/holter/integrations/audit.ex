defmodule Holter.Integrations.Audit do
  @moduledoc """
  Pure transformer — builds audit log attribute maps for integration
  lifecycle events. No Repo, no DateTime.utc_now/0, no side effects.
  Coordinators pass `now` and persist via `Holter.Integrations.IntegrationAuditLogs`.
  """

  def build_connected_audit(actor_id, workspace_id, %{provider: provider, now: now}) do
    %{
      actor_id: actor_id,
      actor_type: "user",
      workspace_id: workspace_id,
      resource: "integration:#{provider}",
      action: "integrations.connected",
      diff: %{},
      occurred_at: now
    }
  end

  def build_disconnected_audit(actor_id, workspace_id, %{provider: provider, now: now}) do
    %{
      actor_id: actor_id,
      actor_type: "user",
      workspace_id: workspace_id,
      resource: "integration:#{provider}",
      action: "integrations.disconnected",
      diff: %{},
      occurred_at: now
    }
  end

  def build_action_dispatched_audit(workspace_id, provider, %{event: event, now: now}) do
    %{
      actor_id: nil,
      actor_type: "system",
      workspace_id: workspace_id,
      resource: "integration:#{provider}",
      action: "integrations.action_dispatched",
      diff: %{"event" => event},
      occurred_at: now
    }
  end

  def build_reauth_failed_audit(workspace_id, provider, %{now: now}) do
    %{
      actor_id: nil,
      actor_type: "system",
      workspace_id: workspace_id,
      resource: "integration:#{provider}",
      action: "integrations.reauth_failed",
      diff: %{},
      occurred_at: now
    }
  end

  def build_rule_created_audit(actor_id, workspace_id, %{rule: rule, now: now}) do
    %{
      actor_id: actor_id,
      actor_type: "user",
      workspace_id: workspace_id,
      resource: "integration_rule:#{rule.id}",
      action: "integrations.rule_created",
      diff: %{
        "monitor_id" => rule.monitor_id,
        "event_type" => rule.event_type,
        "target_type" => rule.target_type,
        "target_id" => rule.target_id
      },
      occurred_at: now
    }
  end

  def build_rule_deleted_audit(actor_id, workspace_id, %{rule: rule, now: now}) do
    %{
      actor_id: actor_id,
      actor_type: "user",
      workspace_id: workspace_id,
      resource: "integration_rule:#{rule.id}",
      action: "integrations.rule_deleted",
      diff: %{
        "monitor_id" => rule.monitor_id,
        "event_type" => rule.event_type,
        "target_type" => rule.target_type,
        "target_id" => rule.target_id
      },
      occurred_at: now
    }
  end
end
