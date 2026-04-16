defmodule Holter.Repo.Migrations.AddRedirectListToMonitorLogs do
  use Ecto.Migration

  def change do
    alter table(:monitor_logs) do
      add :redirect_list, {:array, :map}, default: []
    end
  end
end
