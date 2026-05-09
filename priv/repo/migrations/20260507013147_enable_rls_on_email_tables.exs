defmodule Holter.Repo.Migrations.EnableRlsOnEmailTables do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE email_channels ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE email_channels FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON email_channels
      USING (
        workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        OR
        EXISTS (
          SELECT 1 FROM workspace_memberships wm
          WHERE wm.workspace_id = email_channels.workspace_id
            AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
        )
      )
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)

    execute("ALTER TABLE email_channel_recipients ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE email_channel_recipients FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON email_channel_recipients
      USING (
        EXISTS (
          SELECT 1 FROM email_channels ec
          WHERE ec.id = email_channel_recipients.email_channel_id
            AND ec.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
        OR
        EXISTS (
          SELECT 1 FROM email_channels ec
          JOIN workspace_memberships wm ON wm.workspace_id = ec.workspace_id
          WHERE ec.id = email_channel_recipients.email_channel_id
            AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM email_channels ec
          WHERE ec.id = email_channel_recipients.email_channel_id
            AND ec.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
    """)

    execute("ALTER TABLE monitor_email_channels ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitor_email_channels FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON monitor_email_channels
      USING (
        (
          EXISTS (
            SELECT 1 FROM monitors m
            WHERE m.id = monitor_email_channels.monitor_id
              AND m.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
          )
          AND EXISTS (
            SELECT 1 FROM email_channels ec
            WHERE ec.id = monitor_email_channels.email_channel_id
              AND ec.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
          )
        )
        OR
        (
          EXISTS (
            SELECT 1 FROM monitors m
            JOIN workspace_memberships wm ON wm.workspace_id = m.workspace_id
            WHERE m.id = monitor_email_channels.monitor_id
              AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
          )
          AND EXISTS (
            SELECT 1 FROM email_channels ec
            JOIN workspace_memberships wm ON wm.workspace_id = ec.workspace_id
            WHERE ec.id = monitor_email_channels.email_channel_id
              AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
          )
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM monitors m
          WHERE m.id = monitor_email_channels.monitor_id
            AND m.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
        AND EXISTS (
          SELECT 1 FROM email_channels ec
          WHERE ec.id = monitor_email_channels.email_channel_id
            AND ec.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
      )
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS tenant_isolation ON monitor_email_channels")
    execute("ALTER TABLE monitor_email_channels NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitor_email_channels DISABLE ROW LEVEL SECURITY")

    execute("DROP POLICY IF EXISTS tenant_isolation ON email_channel_recipients")
    execute("ALTER TABLE email_channel_recipients NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE email_channel_recipients DISABLE ROW LEVEL SECURITY")

    execute("DROP POLICY IF EXISTS tenant_isolation ON email_channels")
    execute("ALTER TABLE email_channels NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE email_channels DISABLE ROW LEVEL SECURITY")
  end
end
