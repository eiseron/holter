defmodule Holter.Repo.Migrations.CreateMonitorNotifications do
  use Ecto.Migration

  def change do
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
  end
end
