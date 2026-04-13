defmodule Holter.Repo.Migrations.AddRedirectFieldsToMonitorLogs do
  use Ecto.Migration

  def change do
    alter table(:monitor_logs) do
      add :redirect_count, :integer
      add :last_redirect_url, :string
    end
  end
end
