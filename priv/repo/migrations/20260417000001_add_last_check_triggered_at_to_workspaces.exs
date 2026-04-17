defmodule Holter.Repo.Migrations.AddLastCheckTriggeredAtToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :last_check_triggered_at, :utc_datetime, null: true
    end
  end
end
