defmodule Holter.Repo.Migrations.EnableRlsOnWebhookChannels do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE webhook_channels ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE webhook_channels FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON webhook_channels
      USING      (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON webhook_channels")
    execute("ALTER TABLE webhook_channels NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE webhook_channels DISABLE ROW LEVEL SECURITY")
  end
end
