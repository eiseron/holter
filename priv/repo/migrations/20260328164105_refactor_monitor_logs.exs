defmodule Holter.Repo.Migrations.RefactorMonitorLogs do
  use Ecto.Migration

  def change do
    rename table(:monitor_logs), :http_status, to: :status_code
    rename table(:monitor_logs), :response_time_ms, to: :latency_ms

    alter table(:monitor_logs) do
      add :region, :string
      add :response_snippet, :text
    end
  end
end
