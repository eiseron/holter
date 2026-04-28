defmodule Holter.Repo.Migrations.AddLastTestDispatchedAtToNotificationChannels do
  use Ecto.Migration

  def up do
    alter table(:notification_channels) do
      add :last_test_dispatched_at, :utc_datetime, null: true
    end
  end

  def down do
    alter table(:notification_channels) do
      remove :last_test_dispatched_at
    end
  end
end
