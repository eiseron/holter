defmodule Holter.Repo.Migrations.PromoteChannelSubtypeColumns do
  @moduledoc """
  Step 1 of splitting `notification_channels` into two standalone entities (issue #29).

  Promotes `workspace_id`, `name`, and `last_test_dispatched_at` from the
  `notification_channels` parent onto each subtype table so they can stand on
  their own. Backfills from the parent and asserts NOT NULL on the new keys.

  The parent table still exists and stays in sync via the existing changeset
  flow. A later migration drops the parent + the `notification_channel_id` FK.
  """
  use Ecto.Migration

  def up do
    alter table(:webhook_channels) do
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
      add :name, :string
      add :last_test_dispatched_at, :utc_datetime
    end

    alter table(:email_channels) do
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
      add :name, :string
      add :last_test_dispatched_at, :utc_datetime
    end

    flush()

    execute("""
    UPDATE webhook_channels w
    SET workspace_id = nc.workspace_id,
        name = nc.name,
        last_test_dispatched_at = nc.last_test_dispatched_at
    FROM notification_channels nc
    WHERE w.notification_channel_id = nc.id
    """)

    execute("""
    UPDATE email_channels e
    SET workspace_id = nc.workspace_id,
        name = nc.name,
        last_test_dispatched_at = nc.last_test_dispatched_at
    FROM notification_channels nc
    WHERE e.notification_channel_id = nc.id
    """)

    execute("ALTER TABLE webhook_channels ALTER COLUMN workspace_id SET NOT NULL")
    execute("ALTER TABLE webhook_channels ALTER COLUMN name SET NOT NULL")
    execute("ALTER TABLE email_channels ALTER COLUMN workspace_id SET NOT NULL")
    execute("ALTER TABLE email_channels ALTER COLUMN name SET NOT NULL")

    create index(:webhook_channels, [:workspace_id])
    create index(:email_channels, [:workspace_id])
  end

  def down do
    drop index(:webhook_channels, [:workspace_id])
    drop index(:email_channels, [:workspace_id])

    alter table(:webhook_channels) do
      remove :workspace_id
      remove :name
      remove :last_test_dispatched_at
    end

    alter table(:email_channels) do
      remove :workspace_id
      remove :name
      remove :last_test_dispatched_at
    end
  end
end
