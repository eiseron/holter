defmodule Holter.Repo.Migrations.AddOrganizationIdToMonitors do
  use Ecto.Migration

  def change do
    alter table(:monitors) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false
    end

    create index(:monitors, [:organization_id])
  end
end
