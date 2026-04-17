defmodule Holter.Repo.Migrations.AddCreateBudgetToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :max_creates_per_minute, :integer, default: 5, null: false
      add :max_creates_per_hour, :integer, default: 20, null: false
      add :create_short_count, :integer, default: 0, null: false
      add :create_short_window_start, :utc_datetime
      add :create_long_count, :integer, default: 0, null: false
      add :create_long_window_start, :utc_datetime
    end
  end
end
