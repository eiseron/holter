defmodule Holter.Repo.Migrations.CreateNotificationChannelLogs do
  use Ecto.Migration

  def change do
    create table(:notification_channel_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :notification_channel_id,
          references(:notification_channels, type: :binary_id, on_delete: :delete_all),
          null: false

      add :status, :string, null: false
      add :event_type, :string, null: false
      add :error_message, :string
      add :monitor_id, references(:monitors, type: :binary_id, on_delete: :nilify_all)
      add :incident_id, references(:incidents, type: :binary_id, on_delete: :nilify_all)
      add :dispatched_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:notification_channel_logs, [:notification_channel_id])
    create index(:notification_channel_logs, [:dispatched_at])
  end
end
