DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'holter_app_login') THEN
    CREATE ROLE holter_app_login LOGIN PASSWORD 'holter_app' IN ROLE holter_app;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'holter_admin_login') THEN
    CREATE ROLE holter_admin_login LOGIN BYPASSRLS CREATEDB PASSWORD 'holter_admin' IN ROLE holter_admin;
  END IF;
END
$$;

GRANT CONNECT ON DATABASE holter_dev TO holter_app_login, holter_admin_login;
GRANT CREATE ON DATABASE holter_dev TO holter_admin_login;
GRANT USAGE ON SCHEMA public TO holter_app_login, holter_admin_login;
GRANT CREATE ON SCHEMA public TO holter_admin_login;

ALTER DEFAULT PRIVILEGES FOR ROLE holter_admin_login IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO holter_app_login;

ALTER DEFAULT PRIVILEGES FOR ROLE holter_admin_login IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO holter_app_login;
