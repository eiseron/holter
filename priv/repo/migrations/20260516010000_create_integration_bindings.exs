defmodule Holter.Repo.Migrations.CreateIntegrationBindings do
  use Ecto.Migration

  def up do
    create table(:integration_bindings, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :monitor_id, references(:monitors, type: :binary_id, on_delete: :delete_all),
        null: false

      add :event_type, :string, null: false
      add :action, :string, null: false
      add :target_type, :string, null: false
      add :target_id, :string, null: false
      add :target_label, :string

      timestamps(type: :utc_datetime)
    end

    create index(:integration_bindings, [:integration_id])
    create index(:integration_bindings, [:monitor_id, :event_type])

    create unique_index(
             :integration_bindings,
             [:integration_id, :monitor_id, :event_type, :action, :target_id],
             name: :integration_bindings_uniqueness_index
           )

    execute("ALTER TABLE integration_bindings ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE integration_bindings FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON integration_bindings
      USING (
        EXISTS (
          SELECT 1 FROM integrations i
          WHERE i.id = integration_bindings.integration_id
            AND i.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM integrations i
          WHERE i.id = integration_bindings.integration_id
            AND i.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON integration_bindings")
    execute("ALTER TABLE integration_bindings NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE integration_bindings DISABLE ROW LEVEL SECURITY")
    drop table(:integration_bindings)
  end
end
