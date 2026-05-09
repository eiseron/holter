defmodule Holter.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def up do
    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :hashed_value, :bytea, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_tokens, [:hashed_value])
    create index(:api_tokens, [:user_id, :workspace_id])
    create index(:api_tokens, [:workspace_id])

    execute("ALTER TABLE api_tokens ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE api_tokens FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY workspace_isolation ON api_tokens
      USING      (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)

    execute("""
    CREATE OR REPLACE FUNCTION auth_lookup_api_token(p_hashed bytea)
      RETURNS TABLE (
        id uuid,
        user_id uuid,
        workspace_id uuid,
        scopes text[],
        expires_at timestamptz,
        last_used_at timestamptz,
        revoked_at timestamptz,
        inserted_at timestamptz,
        name text
      )
      SECURITY DEFINER
      STABLE
      LANGUAGE sql
    AS $fn$
      SELECT id, user_id, workspace_id, scopes, expires_at, last_used_at,
             revoked_at, inserted_at, name
      FROM api_tokens
      WHERE hashed_value = p_hashed
        AND revoked_at IS NULL
        AND (expires_at IS NULL OR expires_at > NOW());
    $fn$
    """)

    execute("REVOKE ALL ON FUNCTION auth_lookup_api_token(bytea) FROM PUBLIC")
    execute("GRANT EXECUTE ON FUNCTION auth_lookup_api_token(bytea) TO holter_app")

    execute("""
    CREATE OR REPLACE FUNCTION revoke_api_tokens_on_membership_delete()
      RETURNS TRIGGER
      SECURITY DEFINER
      LANGUAGE plpgsql
    AS $fn$
    BEGIN
      UPDATE api_tokens
        SET revoked_at = NOW()
        WHERE user_id = OLD.user_id
          AND workspace_id = OLD.workspace_id
          AND revoked_at IS NULL;
      RETURN OLD;
    END;
    $fn$
    """)

    execute("""
    CREATE TRIGGER api_tokens_revoke_on_membership_delete
      AFTER DELETE ON workspace_memberships
      FOR EACH ROW
      EXECUTE FUNCTION revoke_api_tokens_on_membership_delete()
    """)
  end

  def down do
    execute(
      "DROP TRIGGER IF EXISTS api_tokens_revoke_on_membership_delete ON workspace_memberships"
    )

    execute("DROP FUNCTION IF EXISTS revoke_api_tokens_on_membership_delete()")
    execute("DROP FUNCTION IF EXISTS auth_lookup_api_token(bytea)")
    execute("DROP POLICY IF EXISTS workspace_isolation ON api_tokens")
    execute("ALTER TABLE api_tokens NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE api_tokens DISABLE ROW LEVEL SECURITY")
    drop table(:api_tokens)
  end
end
