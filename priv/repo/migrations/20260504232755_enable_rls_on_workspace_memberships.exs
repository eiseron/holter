defmodule Holter.Repo.Migrations.EnableRlsOnWorkspaceMemberships do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE workspace_memberships ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE workspace_memberships FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY user_isolation ON workspace_memberships
      USING      (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
      WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
    """)
  end

  def down do
    execute("DROP POLICY IF EXISTS user_isolation ON workspace_memberships")
    execute("ALTER TABLE workspace_memberships NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE workspace_memberships DISABLE ROW LEVEL SECURITY")
  end
end
