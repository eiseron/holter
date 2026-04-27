defmodule Holter.Repo.Migrations.SplitChannelSubtypes do
  use Ecto.Migration

  def up do
    create table(:webhook_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :url, :string, null: false
      add :settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:webhook_channels, [:notification_channel_id])

    create table(:email_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :address, :string, null: false
      add :settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_channels, [:notification_channel_id])

    flush()

    execute("""
    INSERT INTO webhook_channels (id, notification_channel_id, url, settings, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      id,
      target,
      COALESCE(settings, '{}'::jsonb),
      now() AT TIME ZONE 'utc',
      now() AT TIME ZONE 'utc'
    FROM notification_channels
    WHERE type = 'webhook'
    """)

    execute("""
    INSERT INTO email_channels (id, notification_channel_id, address, settings, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      id,
      target,
      COALESCE(settings, '{}'::jsonb),
      now() AT TIME ZONE 'utc',
      now() AT TIME ZONE 'utc'
    FROM notification_channels
    WHERE type = 'email'
    """)

    alter table(:notification_channels) do
      remove :target
      remove :type
      remove :settings
    end
  end

  def down do
    alter table(:notification_channels) do
      add :type, :string
      add :target, :string
      add :settings, :map, default: %{}
    end

    flush()

    execute("""
    UPDATE notification_channels nc
    SET type = 'webhook', target = wc.url, settings = wc.settings
    FROM webhook_channels wc
    WHERE wc.notification_channel_id = nc.id
    """)

    execute("""
    UPDATE notification_channels nc
    SET type = 'email', target = ec.address, settings = ec.settings
    FROM email_channels ec
    WHERE ec.notification_channel_id = nc.id
    """)

    execute("ALTER TABLE notification_channels ALTER COLUMN type SET NOT NULL")
    execute("ALTER TABLE notification_channels ALTER COLUMN target SET NOT NULL")

    drop table(:email_channels)
    drop table(:webhook_channels)
  end
end
