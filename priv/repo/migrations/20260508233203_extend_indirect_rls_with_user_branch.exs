defmodule Holter.Repo.Migrations.ExtendIndirectRlsWithUserBranch do
  use Ecto.Migration

  @tables_anchored_on_monitors ~w(incidents monitor_logs daily_metrics)

  def up do
    Enum.each(@tables_anchored_on_monitors, &replace_indirect_with_user_branch/1)
    replace_webhook_channels_with_user_branch()
  end

  def down do
    Enum.each(@tables_anchored_on_monitors, &restore_indirect_workspace_only/1)
    restore_webhook_channels_workspace_only()
  end

  defp replace_indirect_with_user_branch(table) do
    execute("DROP POLICY IF EXISTS tenant_isolation ON #{table}")

    execute("""
    CREATE POLICY tenant_isolation ON #{table}
      USING (
        EXISTS (
          SELECT 1 FROM monitors m
          WHERE m.id = #{table}.monitor_id
            AND m.workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        )
        OR
        EXISTS (
          SELECT 1 FROM monitors m
          JOIN workspace_memberships wm ON wm.workspace_id = m.workspace_id
          WHERE m.id = #{table}.monitor_id
            AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
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

  defp restore_indirect_workspace_only(table) do
    execute("DROP POLICY IF EXISTS tenant_isolation ON #{table}")

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

  defp replace_webhook_channels_with_user_branch do
    execute("DROP POLICY IF EXISTS tenant_isolation ON webhook_channels")

    execute("""
    CREATE POLICY tenant_isolation ON webhook_channels
      USING (
        workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
        OR
        EXISTS (
          SELECT 1 FROM workspace_memberships wm
          WHERE wm.workspace_id = webhook_channels.workspace_id
            AND wm.user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
        )
      )
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)
  end

  defp restore_webhook_channels_workspace_only do
    execute("DROP POLICY IF EXISTS tenant_isolation ON webhook_channels")

    execute("""
    CREATE POLICY tenant_isolation ON webhook_channels
      USING      (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)
  end
end
