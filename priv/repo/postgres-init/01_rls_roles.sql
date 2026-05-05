DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'holter_admin') THEN
    CREATE ROLE holter_admin NOLOGIN BYPASSRLS;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'holter_app') THEN
    CREATE ROLE holter_app NOLOGIN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_auth_members am
    JOIN pg_roles r1 ON am.member = r1.oid
    JOIN pg_roles r2 ON am.roleid = r2.oid
    WHERE r1.rolname = 'holter_admin' AND r2.rolname = 'holter_app'
  ) THEN
    GRANT holter_app TO holter_admin;
  END IF;
END
$$;
