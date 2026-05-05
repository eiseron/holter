defmodule Holter.Repo.Migrations.CreateRlsRoles do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'holter_admin') THEN
        RAISE EXCEPTION 'holter_admin role missing — provision via priv/repo/postgres-init/01_rls_roles.sql (dev) or Ansible postgres_shared (preview/prod)';
      END IF;

      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'holter_app') THEN
        RAISE EXCEPTION 'holter_app role missing — provision via priv/repo/postgres-init/01_rls_roles.sql (dev) or Ansible postgres_shared (preview/prod)';
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM pg_auth_members am
        JOIN pg_roles r1 ON am.member = r1.oid
        JOIN pg_roles r2 ON am.roleid = r2.oid
        WHERE r1.rolname = 'holter_admin' AND r2.rolname = 'holter_app'
      ) THEN
        RAISE EXCEPTION 'holter_admin must inherit holter_app — provision via priv/repo/postgres-init/01_rls_roles.sql (dev) or Ansible postgres_shared (preview/prod)';
      END IF;
    END
    $$;
    """)

    execute("GRANT USAGE ON SCHEMA public TO holter_app")

    execute("""
    GRANT SELECT, INSERT, UPDATE, DELETE
      ON ALL TABLES IN SCHEMA public
      TO holter_app
    """)

    execute("""
    GRANT USAGE, SELECT
      ON ALL SEQUENCES IN SCHEMA public
      TO holter_app
    """)

    execute("""
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO holter_app
    """)

    execute("""
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT USAGE, SELECT ON SEQUENCES TO holter_app
    """)
  end

  def down do
    execute("""
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      REVOKE USAGE, SELECT ON SEQUENCES FROM holter_app
    """)

    execute("""
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM holter_app
    """)

    execute("""
    REVOKE USAGE, SELECT
      ON ALL SEQUENCES IN SCHEMA public
      FROM holter_app
    """)

    execute("""
    REVOKE SELECT, INSERT, UPDATE, DELETE
      ON ALL TABLES IN SCHEMA public
      FROM holter_app
    """)

    execute("REVOKE USAGE ON SCHEMA public FROM holter_app")
  end
end
