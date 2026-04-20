defmodule Holter.Repo.Migrations.AddIncidentIdToMonitorLogs do
  use Ecto.Migration

  def change do
    alter table(:monitor_logs) do
      add :incident_id, references(:incidents, type: :binary_id, on_delete: :nilify_all),
        null: true
    end

    create index(:monitor_logs, [:incident_id])
  end
end
