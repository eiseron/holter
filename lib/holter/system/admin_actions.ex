defmodule Holter.System.AdminActions do
  @moduledoc """
  Pure transformers for admin/audit-log mutations. No `Repo`, no
  `DateTime.utc_now/0`, no broadcasts — coordinators in
  `Holter.System.Admins` and `Holter.System.AuditLogs` own those side
  effects and pass `now` plus the resolved actor in.

  Every function here is exercised by the credo check
  `Holter.Credo.Check.Design.NoSideEffectsInTransformer`; the `build_`
  prefix is the contract.
  """

  alias Holter.Identity.Models.User
  alias Holter.System.Models.Admin

  def build_promotion_attrs(%User{id: user_id}, actor_admin, %DateTime{} = now) do
    %{
      user_id: user_id,
      promoted_by_admin_id: maybe_admin_id(actor_admin),
      promoted_at: DateTime.truncate(now, :second)
    }
  end

  def build_revocation_attrs(%Admin{} = actor_admin, %DateTime{} = now) do
    %{
      revoked_at: DateTime.truncate(now, :second),
      revoked_by_admin_id: actor_admin.id
    }
  end

  def build_audit_diff(:promote, %User{} = target, actor_admin) do
    %{
      "target_user_id" => target.id,
      "target_email" => target.email,
      "actor_admin_id" => maybe_admin_id(actor_admin)
    }
  end

  def build_audit_diff(:demote, %Admin{} = target_admin, %Admin{} = actor_admin) do
    %{
      "target_admin_id" => target_admin.id,
      "target_user_id" => target_admin.user_id,
      "actor_admin_id" => actor_admin.id
    }
  end

  def build_audit_log_attrs(%{actor_type: actor_type} = params, %DateTime{} = now)
      when actor_type in ["admin", "system"] do
    %{
      actor_id: maybe_user_id(Map.get(params, :actor_user)),
      actor_type: actor_type,
      resource: Map.fetch!(params, :resource),
      action: Map.fetch!(params, :action),
      diff: Map.get(params, :diff, %{}),
      occurred_at: now
    }
  end

  defp maybe_admin_id(nil), do: nil
  defp maybe_admin_id(%Admin{id: id}), do: id

  defp maybe_user_id(nil), do: nil
  defp maybe_user_id(%User{id: id}), do: id
end
