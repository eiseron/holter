defmodule Holter.Repo.Migrations.DropNotificationChannelsParent do
  @moduledoc """
  Final structural step of #29's split. Drops the `notification_channels`
  parent table and the `notification_channel_id` FK column on each
  subtype. After this migration, `webhook_channels` and `email_channels`
  are fully standalone entities — no shared parent.

  Reversal recreates the parent table and FK columns and walks the
  subtype rows back into a parent row each, picking up the subtype's
  workspace_id/name/last_test_dispatched_at to populate the parent.
  """
  use Ecto.Migration

  def up do
    drop_if_exists unique_index(:webhook_channels, [:notification_channel_id])
    drop_if_exists unique_index(:email_channels, [:notification_channel_id])

    alter table(:webhook_channels) do
      remove :notification_channel_id
    end

    alter table(:email_channels) do
      remove :notification_channel_id
    end

    drop table(:notification_channels)
  end

  def down do
    create table(:notification_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :last_test_dispatched_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:notification_channels, [:workspace_id])

    alter table(:webhook_channels) do
      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:email_channels) do
      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all)
    end

    flush()

    execute("""
    INSERT INTO notification_channels (id, workspace_id, name, last_test_dispatched_at, inserted_at, updated_at)
    SELECT gen_random_uuid(), workspace_id, name, last_test_dispatched_at, inserted_at, updated_at
    FROM webhook_channels
    """)

    execute("""
    UPDATE webhook_channels w
    SET notification_channel_id = nc.id
    FROM notification_channels nc
    WHERE nc.workspace_id = w.workspace_id AND nc.name = w.name
    """)

    execute("""
    INSERT INTO notification_channels (id, workspace_id, name, last_test_dispatched_at, inserted_at, updated_at)
    SELECT gen_random_uuid(), workspace_id, name, last_test_dispatched_at, inserted_at, updated_at
    FROM email_channels
    """)

    execute("""
    UPDATE email_channels e
    SET notification_channel_id = nc.id
    FROM notification_channels nc
    WHERE nc.workspace_id = e.workspace_id AND nc.name = e.name
      AND e.notification_channel_id IS NULL
    """)

    create unique_index(:webhook_channels, [:notification_channel_id])
    create unique_index(:email_channels, [:notification_channel_id])
  end
end
