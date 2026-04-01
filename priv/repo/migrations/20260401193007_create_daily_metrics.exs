defmodule Holter.Repo.Migrations.CreateDailyMetrics do
  use Ecto.Migration

  def change do
    create table(:daily_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :monitor_id, references(:monitors, on_delete: :delete_all, type: :binary_id),
        null: false

      add :date, :date, null: false
      add :uptime_percent, :decimal, precision: 5, scale: 2, default: 0.0, null: false
      add :avg_latency_ms, :integer, default: 0, null: false
      add :total_downtime_minutes, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:daily_metrics, [:monitor_id])
    create unique_index(:daily_metrics, [:monitor_id, :date])
  end
end
