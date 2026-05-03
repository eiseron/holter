defmodule Holter.Repo.Migrations.RenameRecipientsToEmailChannel do
  @moduledoc """
  Step 4 of #29's split. Renames `notification_channel_recipients` →
  `email_channel_recipients` and rewires the FK from the legacy parent
  to the standalone email_channel.

  Existing rows are remapped via the parent → email_channels relation,
  preserving recipient identities, tokens, and verification timestamps.
  """
  use Ecto.Migration

  def up do
    rename table(:notification_channel_recipients), to: table(:email_channel_recipients)

    alter table(:email_channel_recipients) do
      add :email_channel_id,
          references(:email_channels, type: :binary_id, on_delete: :delete_all)
    end

    flush()

    execute("""
    UPDATE email_channel_recipients r
    SET email_channel_id = e.id
    FROM email_channels e
    WHERE e.notification_channel_id = r.notification_channel_id
    """)

    execute("ALTER TABLE email_channel_recipients ALTER COLUMN email_channel_id SET NOT NULL")

    drop_if_exists index(:notification_channel_recipients, [:notification_channel_id])

    drop_if_exists unique_index(:notification_channel_recipients, [:token],
                     name: "notification_channel_recipients_token_index"
                   )

    drop_if_exists unique_index(
                     :notification_channel_recipients,
                     [:notification_channel_id, :email],
                     name: "notification_channel_recipients_notification_channel_id_email_i"
                   )

    alter table(:email_channel_recipients) do
      remove :notification_channel_id
    end

    create index(:email_channel_recipients, [:email_channel_id])
    create unique_index(:email_channel_recipients, [:token], where: "token IS NOT NULL")
    create unique_index(:email_channel_recipients, [:email_channel_id, :email])
  end

  def down do
    drop_if_exists index(:email_channel_recipients, [:email_channel_id])
    drop_if_exists unique_index(:email_channel_recipients, [:token])
    drop_if_exists unique_index(:email_channel_recipients, [:email_channel_id, :email])

    alter table(:email_channel_recipients) do
      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all)
    end

    flush()

    execute("""
    UPDATE email_channel_recipients r
    SET notification_channel_id = e.notification_channel_id
    FROM email_channels e
    WHERE e.id = r.email_channel_id AND e.notification_channel_id IS NOT NULL
    """)

    execute(
      "ALTER TABLE email_channel_recipients ALTER COLUMN notification_channel_id SET NOT NULL"
    )

    alter table(:email_channel_recipients) do
      remove :email_channel_id
    end

    rename table(:email_channel_recipients), to: table(:notification_channel_recipients)

    create index(:notification_channel_recipients, [:notification_channel_id])
    create unique_index(:notification_channel_recipients, [:token], where: "token IS NOT NULL")
    create unique_index(:notification_channel_recipients, [:notification_channel_id, :email])
  end
end
