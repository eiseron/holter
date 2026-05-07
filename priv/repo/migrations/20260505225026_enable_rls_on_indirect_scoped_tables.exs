defmodule Holter.Repo.Migrations.EnableRlsOnIndirectScopedTables do
  use Ecto.Migration

  @tables_anchored_on_monitors ~w(incidents monitor_logs daily_metrics)

  def up do
    Enum.each(@tables_anchored_on_monitors, &enable_monitor_anchored/1)

    execute("ALTER TABLE monitor_webhook_channels ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitor_webhook_channels FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON monitor_webhook_channels
      USING (
        EXISTS (
          SELECT 1 FROM monitors m
          WHERE m.id = monitor_webhook_channels.monitor_id
            AND m.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
        AND EXISTS (
          SELECT 1 FROM webhook_channels wc
          WHERE wc.id = monitor_webhook_channels.webhook_channel_id
            AND wc.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM monitors m
          WHERE m.id = monitor_webhook_channels.monitor_id
            AND m.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
        AND EXISTS (
          SELECT 1 FROM webhook_channels wc
          WHERE wc.id = monitor_webhook_channels.webhook_channel_id
            AND wc.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON monitor_webhook_channels")
    execute("ALTER TABLE monitor_webhook_channels NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitor_webhook_channels DISABLE ROW LEVEL SECURITY")

    Enum.each(@tables_anchored_on_monitors, fn table ->
      execute("DROP POLICY IF EXISTS tenant_isolation ON #{table}")
      execute("ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY")
      execute("ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY")
    end)
  end

  defp enable_monitor_anchored(table) do
    execute("ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE #{table} FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON #{table}
      USING (
        EXISTS (
          SELECT 1 FROM monitors m
          WHERE m.id = #{table}.monitor_id
            AND m.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM monitors m
          WHERE m.id = #{table}.monitor_id
            AND m.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
    """)
  end
end
