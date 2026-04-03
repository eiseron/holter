defmodule Holter.Monitoring.Logs do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.MonitorLog
  alias Holter.Repo

  def list_monitor_logs(monitor_id) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> order_by([l], desc: l.checked_at, desc: l.inserted_at)
    |> limit(100)
    |> Repo.all()
  end

  def get_monitor_log!(id), do: Repo.get!(MonitorLog, id)

  def create_monitor_log(attrs \\ %{}) do
    case %MonitorLog{}
         |> MonitorLog.changeset(attrs)
         |> Repo.insert() do
      {:ok, log} ->
        broadcast({:ok, log}, :log_created)
        {:ok, log}

      error ->
        error
    end
  end

  defp broadcast({:ok, log}, event) do
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitor:#{log.monitor_id}", {event, log})
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitors", {event, log})
    {:ok, log}
  end

  defp broadcast(error, _), do: error

  @doc """
  Deletes a chunk of logs older than the retention days for a specific monitor.
  Returns the number of deleted records.
  """
  def prune_logs_chunk(monitor_id, days_to_keep \\ 3, chunk_size \\ 500) do
    threshold =
      DateTime.utc_now() |> DateTime.add(-days_to_keep, :day) |> DateTime.truncate(:second)

    ids_query =
      from l in MonitorLog,
        where: l.monitor_id == ^monitor_id and l.checked_at < ^threshold,
        order_by: [asc: l.checked_at],
        limit: ^chunk_size,
        select: l.id

    delete_query =
      from l in MonitorLog,
        where: l.id in subquery(ids_query)

    {deleted_count, _} = Repo.delete_all(delete_query)
    deleted_count
  end
end
