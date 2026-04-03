defmodule Holter.Repo.Migrations.AddEvidenceFieldsToMonitorLogs do
  use Ecto.Migration

  def change do
    alter table(:monitor_logs) do
      add :response_headers, :map
      add :response_ip, :string
    end
  end
end
