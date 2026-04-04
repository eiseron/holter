defmodule Holter.Repo.Migrations.AddOrganizationIdToTenantLimits do
  use Ecto.Migration

  def change do
    alter table(:tenant_limits) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all)
    end
  end
end
