defmodule Holter.Repo.Migrations.CreateIncidents do
  use Ecto.Migration

  def change do
    create table(:incidents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :monitor_id, references(:monitors, on_delete: :delete_all, type: :binary_id),
        null: false

      add :type, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :resolved_at, :utc_datetime
      add :duration_seconds, :integer
      add :root_cause, :text

      timestamps(type: :utc_datetime)
    end

    create index(:incidents, [:monitor_id])
    create index(:incidents, [:started_at])
  end
end
