defmodule Holter.Monitoring.Logs do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.MonitorLog
  alias Holter.Repo

  def list_monitor_logs(monitor, filters) do
    from(l in MonitorLog)
    |> where(monitor_id: ^monitor.id)
    |> apply_status_filter(filters["status"])
    |> apply_date_range_filter(filters["start_date"], filters["end_date"])
    |> order_by([l], desc: l.checked_at, desc: l.inserted_at)
    |> limit(100)
    |> Repo.all()
  end

  defp apply_status_filter(query, nil), do: query

  defp apply_status_filter(query, status),
    do: where(query, [l], l.status == ^String.to_atom(status))

  defp apply_date_range_filter(query, nil, nil), do: query

  defp apply_date_range_filter(query, start_date, nil) do
    where(query, [l], l.checked_at >= ^start_date)
  end

  defp apply_date_range_filter(query, nil, end_date) do
    where(query, [l], l.checked_at <= ^end_date)
  end

  defp apply_date_range_filter(query, start_date, end_date) do
    where(query, [l], l.checked_at >= ^start_date and l.checked_at <= ^end_date)
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
