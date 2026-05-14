defmodule Holter.Repo.Migrations.CreateIntegrations do
  use Ecto.Migration

  def up do
    create table(:integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :provider, :string, null: false
      add :status, :string, null: false, default: "active"
      add :credentials_encrypted, :binary
      add :settings, :map, default: %{}, null: false
      add :subscribed_events, {:array, :string}, default: [], null: false
      add :last_sync_at, :utc_datetime
      add :last_error_at, :utc_datetime
      add :last_error_reason, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:integrations, [:workspace_id, :provider],
             name: :integrations_workspace_id_provider_index
           )

    execute("ALTER TABLE integrations ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE integrations FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON integrations
      USING (
        workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        OR
        EXISTS (
          SELECT 1 FROM workspace_memberships wm
          WHERE wm.workspace_id = integrations.workspace_id
            AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
        )
      )
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)

    create table(:integration_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :direction, :string, null: false
      add :action, :string, null: false
      add :target, :string
      add :payload_redacted, :map, default: %{}
      add :status, :string, null: false
      add :duration_ms, :integer
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:integration_events, [:integration_id, :occurred_at])

    execute("ALTER TABLE integration_events ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE integration_events FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON integration_events
      USING (
        EXISTS (
          SELECT 1 FROM integrations i
          WHERE i.id = integration_events.integration_id
            AND i.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM integrations i
          WHERE i.id = integration_events.integration_id
            AND i.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON integration_events")
    execute("ALTER TABLE integration_events NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE integration_events DISABLE ROW LEVEL SECURITY")
    drop table(:integration_events)

    execute("DROP POLICY IF EXISTS tenant_isolation ON integrations")
    execute("ALTER TABLE integrations NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE integrations DISABLE ROW LEVEL SECURITY")
    drop table(:integrations)
  end
end
