defmodule Holter.Integrations.IntegrationAuditLogs do
  @moduledoc """
  Coordinator that persists integration audit entries into the
  context-owned `integration_audit_logs` table. Relies on the caller's
  active workspace GUC for the RLS `WITH CHECK`.
  """

  alias Holter.Integrations.Models.IntegrationAuditLog
  alias Holter.Repo

  def log_attrs!(attrs) when is_map(attrs) do
    %IntegrationAuditLog{}
    |> IntegrationAuditLog.insert_changeset(attrs)
    |> Repo.insert!()
  end
end
