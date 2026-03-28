defmodule Holter.Repo.Migrations.CreateMonitors do
  use Ecto.Migration

  def change do
    create table(:monitors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id # null for now until Auth is applied
      
      add :logical_state, :string, default: "active", null: false
      add :health_status, :string, default: "unknown", null: false
      
      add :url, :string, null: false
      add :method, :string, default: "GET", null: false
      
      add :interval_seconds, :integer, default: 60, null: false
      add :timeout_seconds, :integer, default: 30, null: false
      
      add :headers, :map, default: %{}
      add :body, :text
      
      add :ssl_ignore, :boolean, default: false, null: false
      add :keyword_positive, {:array, :string}, default: []
      add :keyword_negative, {:array, :string}, default: []
      
      add :last_checked_at, :utc_datetime
      add :last_success_at, :utc_datetime
      add :last_manual_check_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
    
    create index(:monitors, [:user_id])
    create index(:monitors, [:logical_state])
  end
end
