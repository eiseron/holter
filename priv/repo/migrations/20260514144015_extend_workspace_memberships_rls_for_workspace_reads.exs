defmodule Holter.Repo.Migrations.ExtendWorkspaceMembershipsRlsForWorkspaceReads do
  use Ecto.Migration

  def up do
    execute("DROP POLICY IF EXISTS user_isolation ON workspace_memberships")

    execute("""
    CREATE POLICY workspace_member_visibility ON workspace_memberships
      USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
        OR workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid
      )
      WITH CHECK (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
      )
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS workspace_member_visibility ON workspace_memberships")

    execute("""
    CREATE POLICY user_isolation ON workspace_memberships
      USING      (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
      WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
    """)
  end
end
