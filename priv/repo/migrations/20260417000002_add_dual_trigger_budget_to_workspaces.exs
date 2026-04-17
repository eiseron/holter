defmodule Holter.Repo.Migrations.AddDualTriggerBudgetToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :max_triggers_per_minute, :integer, default: 3, null: false
      add :max_triggers_per_hour, :integer, default: 20, null: false
      add :trigger_short_count, :integer, default: 0, null: false
      add :trigger_short_window_start, :utc_datetime, null: true
      add :trigger_long_count, :integer, default: 0, null: false
      add :trigger_long_window_start, :utc_datetime, null: true
    end
  end
end
