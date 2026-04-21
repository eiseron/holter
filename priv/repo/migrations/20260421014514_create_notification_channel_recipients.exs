defmodule Holter.Repo.Migrations.CreateNotificationChannelRecipients do
  use Ecto.Migration

  def change do
    create table(:notification_channel_recipients, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :email, :string, null: false
      add :token, :string
      add :token_expires_at, :naive_datetime
      add :verified_at, :naive_datetime

      timestamps()
    end

    create index(:notification_channel_recipients, [:notification_channel_id])
    create unique_index(:notification_channel_recipients, [:token], where: "token IS NOT NULL")
    create unique_index(:notification_channel_recipients, [:notification_channel_id, :email])
  end
end
