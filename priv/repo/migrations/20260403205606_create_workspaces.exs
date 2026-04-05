defmodule Holter.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      
      add :retention_days, :integer, default: 3, null: false
      add :max_monitors, :integer, default: 3, null: false
      add :min_interval_seconds, :integer, default: 600, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspaces, [:slug])
  end
end
