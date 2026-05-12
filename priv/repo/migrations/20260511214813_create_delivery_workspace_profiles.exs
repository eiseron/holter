defmodule Holter.Repo.Migrations.CreateDeliveryWorkspaceProfiles do
  use Ecto.Migration

  def up do
    create table(:delivery_workspace_profiles, primary_key: false) do
      add :workspace_id,
          references(:workspaces, type: :binary_id, on_delete: :delete_all),
          primary_key: true

      add :max_channels, :integer, default: 2, null: false

      timestamps(type: :utc_datetime)
    end

    execute("""
    INSERT INTO delivery_workspace_profiles (workspace_id, max_channels, inserted_at, updated_at)
    SELECT id, 2, NOW(), NOW() FROM workspaces
    """)

    execute("ALTER TABLE delivery_workspace_profiles ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE delivery_workspace_profiles FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON delivery_workspace_profiles
      USING      (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON delivery_workspace_profiles")
    execute("ALTER TABLE delivery_workspace_profiles NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE delivery_workspace_profiles DISABLE ROW LEVEL SECURITY")

    drop table(:delivery_workspace_profiles)
  end
end
