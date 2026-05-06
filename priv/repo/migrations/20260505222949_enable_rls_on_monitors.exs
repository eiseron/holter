defmodule Holter.Repo.Migrations.EnableRlsOnMonitors do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE monitors ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitors FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON monitors
      USING (
        workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        OR
        EXISTS (
          SELECT 1 FROM workspace_memberships wm
          WHERE wm.workspace_id = monitors.workspace_id
            AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
        )
      )
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON monitors")
    execute("ALTER TABLE monitors NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitors DISABLE ROW LEVEL SECURITY")
  end
end
