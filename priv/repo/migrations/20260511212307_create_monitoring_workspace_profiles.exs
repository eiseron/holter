defmodule Holter.Repo.Migrations.CreateMonitoringWorkspaceProfiles do
  use Ecto.Migration

  def up do
    create table(:monitoring_workspace_profiles, primary_key: false) do
      add :workspace_id,
          references(:workspaces, type: :binary_id, on_delete: :delete_all),
          primary_key: true

      add :retention_days, :integer, default: 3, null: false
      add :max_monitors, :integer, default: 3, null: false
      add :min_interval_seconds, :integer, default: 600, null: false
      add :last_check_triggered_at, :utc_datetime

      add :max_triggers_per_minute, :integer, default: 3, null: false
      add :max_triggers_per_hour, :integer, default: 20, null: false
      add :trigger_short_count, :integer, default: 0, null: false
      add :trigger_short_window_start, :utc_datetime
      add :trigger_long_count, :integer, default: 0, null: false
      add :trigger_long_window_start, :utc_datetime

      add :max_creates_per_minute, :integer, default: 5, null: false
      add :max_creates_per_hour, :integer, default: 20, null: false
      add :create_short_count, :integer, default: 0, null: false
      add :create_short_window_start, :utc_datetime
      add :create_long_count, :integer, default: 0, null: false
      add :create_long_window_start, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    execute("""
    INSERT INTO monitoring_workspace_profiles (
      workspace_id, retention_days, max_monitors, min_interval_seconds,
      last_check_triggered_at,
      max_triggers_per_minute, max_triggers_per_hour, trigger_short_count,
      trigger_short_window_start, trigger_long_count, trigger_long_window_start,
      max_creates_per_minute, max_creates_per_hour, create_short_count,
      create_short_window_start, create_long_count, create_long_window_start,
      inserted_at, updated_at
    )
    SELECT
      id, retention_days, max_monitors, min_interval_seconds,
      last_check_triggered_at,
      max_triggers_per_minute, max_triggers_per_hour, trigger_short_count,
      trigger_short_window_start, trigger_long_count, trigger_long_window_start,
      max_creates_per_minute, max_creates_per_hour, create_short_count,
      create_short_window_start, create_long_count, create_long_window_start,
      NOW(), NOW()
    FROM workspaces
    """)

    execute("ALTER TABLE monitoring_workspace_profiles ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitoring_workspace_profiles FORCE ROW LEVEL SECURITY")

    execute("""
    CREATE POLICY tenant_isolation ON monitoring_workspace_profiles
      USING      (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
      WITH CHECK (workspace_id = NULLIF(current_setting('app.current_workspace_id', true), '')::uuid)
    """)

    alter table(:workspaces) do
      remove :retention_days
      remove :max_monitors
      remove :min_interval_seconds
      remove :last_check_triggered_at
      remove :max_triggers_per_minute
      remove :max_triggers_per_hour
      remove :trigger_short_count
      remove :trigger_short_window_start
      remove :trigger_long_count
      remove :trigger_long_window_start
      remove :max_creates_per_minute
      remove :max_creates_per_hour
      remove :create_short_count
      remove :create_short_window_start
      remove :create_long_count
      remove :create_long_window_start
    end
  end

  def down do
    alter table(:workspaces) do
      add :retention_days, :integer, default: 3, null: false
      add :max_monitors, :integer, default: 3, null: false
      add :min_interval_seconds, :integer, default: 600, null: false
      add :last_check_triggered_at, :utc_datetime
      add :max_triggers_per_minute, :integer, default: 3, null: false
      add :max_triggers_per_hour, :integer, default: 20, null: false
      add :trigger_short_count, :integer, default: 0, null: false
      add :trigger_short_window_start, :utc_datetime
      add :trigger_long_count, :integer, default: 0, null: false
      add :trigger_long_window_start, :utc_datetime
      add :max_creates_per_minute, :integer, default: 5, null: false
      add :max_creates_per_hour, :integer, default: 20, null: false
      add :create_short_count, :integer, default: 0, null: false
      add :create_short_window_start, :utc_datetime
      add :create_long_count, :integer, default: 0, null: false
      add :create_long_window_start, :utc_datetime
    end

    execute("""
    UPDATE workspaces w
    SET retention_days = p.retention_days,
        max_monitors = p.max_monitors,
        min_interval_seconds = p.min_interval_seconds,
        last_check_triggered_at = p.last_check_triggered_at,
        max_triggers_per_minute = p.max_triggers_per_minute,
        max_triggers_per_hour = p.max_triggers_per_hour,
        trigger_short_count = p.trigger_short_count,
        trigger_short_window_start = p.trigger_short_window_start,
        trigger_long_count = p.trigger_long_count,
        trigger_long_window_start = p.trigger_long_window_start,
        max_creates_per_minute = p.max_creates_per_minute,
        max_creates_per_hour = p.max_creates_per_hour,
        create_short_count = p.create_short_count,
        create_short_window_start = p.create_short_window_start,
        create_long_count = p.create_long_count,
        create_long_window_start = p.create_long_window_start
    FROM monitoring_workspace_profiles p
    WHERE w.id = p.workspace_id
    """)

    execute("DROP POLICY IF EXISTS tenant_isolation ON monitoring_workspace_profiles")
    execute("ALTER TABLE monitoring_workspace_profiles NO FORCE ROW LEVEL SECURITY")
    execute("ALTER TABLE monitoring_workspace_profiles DISABLE ROW LEVEL SECURITY")

    drop table(:monitoring_workspace_profiles)
  end
end
