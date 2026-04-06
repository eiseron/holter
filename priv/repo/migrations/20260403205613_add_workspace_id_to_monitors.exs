defmodule Holter.Repo.Migrations.AddWorkspaceIdToMonitors do
  use Ecto.Migration

  def change do
    alter table(:monitors) do
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
    end

    create index(:monitors, [:workspace_id])
  end
end
