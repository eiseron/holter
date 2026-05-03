defmodule Holter.Repo.Migrations.SplitMonitorNotifications do
  @moduledoc """
  Step 3 of #29's split. Replaces the polymorphic `monitor_notifications`
  join table with two type-specific tables — `monitor_webhook_channels`
  and `monitor_email_channels` — each linking monitors to the standalone
  channel entity directly. Existing rows are split by subtype using the
  legacy `notification_channels.id → webhook_channels.notification_channel_id`
  / `email_channels.notification_channel_id` mapping.
  """
  use Ecto.Migration

  def up do
    create table(:monitor_webhook_channels, primary_key: false) do
      add :monitor_id, references(:monitors, type: :binary_id, on_delete: :delete_all),
        null: false

      add :webhook_channel_id,
          references(:webhook_channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :is_active, :boolean, default: true, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create unique_index(:monitor_webhook_channels, [:monitor_id, :webhook_channel_id])
    create index(:monitor_webhook_channels, [:webhook_channel_id])

    create table(:monitor_email_channels, primary_key: false) do
      add :monitor_id, references(:monitors, type: :binary_id, on_delete: :delete_all),
        null: false

      add :email_channel_id,
          references(:email_channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :is_active, :boolean, default: true, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create unique_index(:monitor_email_channels, [:monitor_id, :email_channel_id])
    create index(:monitor_email_channels, [:email_channel_id])

    flush()

    execute("""
    INSERT INTO monitor_webhook_channels (monitor_id, webhook_channel_id, is_active, inserted_at)
    SELECT mn.monitor_id, w.id, mn.is_active, mn.inserted_at
    FROM monitor_notifications mn
    JOIN webhook_channels w ON w.notification_channel_id = mn.notification_channel_id
    """)

    execute("""
    INSERT INTO monitor_email_channels (monitor_id, email_channel_id, is_active, inserted_at)
    SELECT mn.monitor_id, e.id, mn.is_active, mn.inserted_at
    FROM monitor_notifications mn
    JOIN email_channels e ON e.notification_channel_id = mn.notification_channel_id
    """)

    drop table(:monitor_notifications)
  end

  def down do
    create table(:monitor_notifications, primary_key: false) do
      add :monitor_id, references(:monitors, type: :binary_id, on_delete: :delete_all),
        null: false

      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :is_active, :boolean, default: true, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create unique_index(:monitor_notifications, [:monitor_id, :notification_channel_id])
    create index(:monitor_notifications, [:notification_channel_id])

    flush()

    execute("""
    INSERT INTO monitor_notifications (monitor_id, notification_channel_id, is_active, inserted_at)
    SELECT mwc.monitor_id, w.notification_channel_id, mwc.is_active, mwc.inserted_at
    FROM monitor_webhook_channels mwc
    JOIN webhook_channels w ON w.id = mwc.webhook_channel_id
    WHERE w.notification_channel_id IS NOT NULL
    """)

    execute("""
    INSERT INTO monitor_notifications (monitor_id, notification_channel_id, is_active, inserted_at)
    SELECT mec.monitor_id, e.notification_channel_id, mec.is_active, mec.inserted_at
    FROM monitor_email_channels mec
    JOIN email_channels e ON e.id = mec.email_channel_id
    WHERE e.notification_channel_id IS NOT NULL
    """)

    drop table(:monitor_email_channels)
    drop table(:monitor_webhook_channels)
  end
end
