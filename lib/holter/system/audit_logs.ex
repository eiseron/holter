defmodule Holter.System.AuditLogs do
  @moduledoc """
  Coordinator for the append-only `audit_logs` table. The public surface
  has only one mutator (`log!/1,2`) and one query (`list_audit_logs/1`)
  — there is intentionally no update or delete path. Sibling coordinators
  call `log!/2` from inside their own `Repo.transaction/1` blocks so
  that the audit row commits atomically with the action it describes;
  if the caller's transaction rolls back, the audit row goes with it.

  Input shape for `log!/1,2`:

      %{
        actor_user: %User{} | nil,
        actor_type: "admin" | "system",
        resource: "User:<id>",
        action: "promote_admin",
        diff: %{...}
      }

  When `actor_type` is `"system"`, `actor_user` must be `nil` (and
  `actor_id` in the row will be `NULL`). The check constraint and the
  changeset both enforce that pairing.
  """

  import Ecto.Query

  alias Holter.Repo
  alias Holter.System.AdminActions
  alias Holter.System.Models.AuditLog

  def log!(params, now \\ DateTime.utc_now()) when is_map(params) do
    attrs = AdminActions.build_audit_log_attrs(params, now)

    %AuditLog{}
    |> AuditLog.insert_changeset(attrs)
    |> Repo.insert!()
  end

  def list_audit_logs(filters \\ []) do
    AuditLog
    |> apply_filters(filters)
    |> order_by([a], desc: a.occurred_at)
    |> Repo.all()
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:resource, value}, q -> from a in q, where: a.resource == ^value
      {:action, value}, q -> from a in q, where: a.action == ^value
      {:actor_id, value}, q -> from a in q, where: a.actor_id == ^value
    end)
  end
end
