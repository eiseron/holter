defmodule Holter.Repo.Migrations.UpgradeMonitorLogsTimestampsToUsec do
  use Ecto.Migration

  def change do
    alter table(:monitor_logs) do
      modify :checked_at, :utc_datetime_usec, null: false, from: :utc_datetime
      modify :inserted_at, :utc_datetime_usec, null: false, from: :utc_datetime
      modify :updated_at, :utc_datetime_usec, null: false, from: :utc_datetime
    end
  end
end
