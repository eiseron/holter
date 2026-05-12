defmodule Holter.Monitoring.Workers.LogsPruner do
  @moduledoc """
  Oban worker responsible for chunked and sequential log deletion.
  """
  use Oban.Worker, queue: :metrics, max_attempts: 20

  alias Holter.Monitoring.Logs
  alias Holter.Monitoring.Models.Monitor
  alias Holter.Repo

  @chunk_size 500

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"monitor_id" => monitor_id}}) do
    case Repo.get(Monitor, monitor_id) |> Repo.preload(workspace: :monitoring_profile) do
      nil ->
        :ok

      %Monitor{workspace: %{monitoring_profile: %{retention_days: retention_days}}} ->
        deleted_count = Logs.prune_logs_chunk(monitor_id, retention_days, @chunk_size)

        if deleted_count == @chunk_size do
          %{monitor_id: monitor_id}
          |> __MODULE__.new()
          |> Oban.insert!()
        end

        :ok
    end
  end
end
