defmodule Holter.Repo.Migrations.AddNameToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :name, :string, null: false, default: ""
    end

    drop_if_exists index(:integrations, [:workspace_id, :provider],
                     name: :integrations_workspace_id_provider_index
                   )

    create unique_index(:integrations, [:workspace_id, :provider, :name],
             name: :integrations_workspace_id_provider_name_index
           )
  end
end
