defmodule Holter.Repo.Migrations.CreateMonitorLogs do
  use Ecto.Migration

  def change do
    create table(:monitor_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :monitor_id, references(:monitors, on_delete: :delete_all, type: :binary_id), null: false
      add :status, :string, null: false
      add :http_status, :integer
      add :response_time_ms, :integer
      add :error_message, :text
      add :checked_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:monitor_logs, [:monitor_id])
    create index(:monitor_logs, [:checked_at])
  end
end
