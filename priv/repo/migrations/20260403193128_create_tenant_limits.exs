defmodule Holter.Repo.Migrations.CreateTenantLimits do
  use Ecto.Migration

  def change do
    create table(:tenant_limits, primary_key: false) do
      add :user_id, :binary_id, primary_key: true
      add :retention_days, :integer, default: 3, null: false
      add :max_monitors, :integer, default: 3, null: false
      add :min_interval_seconds, :integer, default: 600, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
