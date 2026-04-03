defmodule Holter.Repo.Migrations.AddMonitorSnapshotToLogsAndIncidents do
  use Ecto.Migration

  def change do
    alter table(:monitor_logs) do
      add :monitor_snapshot, :map
    end

    alter table(:incidents) do
      add :monitor_snapshot, :map
    end
  end
end
