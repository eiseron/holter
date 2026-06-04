defmodule Holter.Repo.Migrations.CreateIntegrationAuditLogs do
  use Ecto.Migration

  def up do
    create table(:integration_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :actor_type, :string, null: false
      add :resource, :string, null: false
      add :action, :string, null: false
      add :diff, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:integration_audit_logs, [:workspace_id, :occurred_at])

    create constraint(:integration_audit_logs, :actor_type_known,
             check: "actor_type IN ('user', 'system')"
           )

    execute("ALTER TABLE integration_audit_logs ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE integration_audit_logs FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON integration_audit_logs
      USING (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON integration_audit_logs")
    drop table(:integration_audit_logs)
  end
end
