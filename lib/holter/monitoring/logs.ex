defmodule Holter.Monitoring.Logs do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.{Broadcaster, DateFilter, MonitorLog, Pagination}
  alias Holter.Repo

  @sortable_columns %{
    "checked_at" => :checked_at,
    "status" => :status,
    "latency_ms" => :latency_ms
  }

  def list_monitor_logs(monitor, filters) do
    page_size = filters[:page_size] || 50
    base_query = build_base_query(monitor.id, filters)

    {total_pages, current_page} = Pagination.calculate(base_query, page_size, filters[:page])

    logs =
      fetch_paginated_logs(base_query, current_page, %{
        page_size: page_size,
        sort_by: filters[:sort_by],
        sort_dir: filters[:sort_dir]
      })

    %{
      logs: logs,
      page_number: current_page,
      total_pages: total_pages,
      page_size: page_size
    }
  end

  defp build_base_query(monitor_id, filters) do
    timezone = filters[:timezone] || "Etc/UTC"

    from(l in MonitorLog, where: l.monitor_id == ^monitor_id)
    |> apply_status_filter(filters[:status])
    |> apply_date_range_filter(
      %{start_date: filters[:start_date], end_date: filters[:end_date]},
      timezone
    )
  end

  defp fetch_paginated_logs(query, page, params) do
    page_size = params.page_size
    sort_by = params.sort_by
    sort_dir = params.sort_dir
    offset = (page - 1) * page_size

    query
    |> apply_sort_order(sort_by, sort_dir)
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  defp apply_sort_order(query, sort_by, sort_dir) do
    field = Map.get(@sortable_columns, to_string(sort_by), :checked_at)
    dir = if sort_dir == "asc", do: :asc, else: :desc
    order_by(query, [l], [{^dir, field(l, ^field)}, desc: l.inserted_at])
  end

  @valid_statuses MapSet.new(["up", "down", "degraded", "compromised", "unknown"])

  defp apply_status_filter(query, nil), do: query
  defp apply_status_filter(query, ""), do: query

  defp apply_status_filter(query, status) do
    if MapSet.member?(@valid_statuses, status) do
      where(query, [l], l.status == ^String.to_existing_atom(status))
    else
      query
    end
  end

  defp apply_date_range_filter(query, %{start_date: nil, end_date: nil}, _timezone), do: query

  defp apply_date_range_filter(query, %{start_date: start_date, end_date: nil}, timezone) do
    case DateFilter.parse_to_datetime(start_date, :start, timezone) do
      {:ok, start_dt} -> where(query, [l], l.checked_at >= ^start_dt)
      _ -> query
    end
  end

  defp apply_date_range_filter(query, %{start_date: nil, end_date: end_date}, timezone) do
    case DateFilter.parse_to_datetime(end_date, :end, timezone) do
      {:ok, end_dt} -> where(query, [l], l.checked_at <= ^end_dt)
      _ -> query
    end
  end

  defp apply_date_range_filter(query, %{start_date: start_date, end_date: end_date}, timezone) do
    case {DateFilter.parse_to_datetime(start_date, :start, timezone),
          DateFilter.parse_to_datetime(end_date, :end, timezone)} do
      {{:ok, start_dt}, {:ok, end_dt}} ->
        where(query, [l], l.checked_at >= ^start_dt and l.checked_at <= ^end_dt)

      {{:ok, start_dt}, _} ->
        where(query, [l], l.checked_at >= ^start_dt)

      {_, {:ok, end_dt}} ->
        where(query, [l], l.checked_at <= ^end_dt)

      _ ->
        query
    end
  end

  def list_recent_logs_for_chart(monitor_id, hours \\ 24) do
    cutoff = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id and l.checked_at >= ^cutoff)
    |> order_by([l], asc: l.checked_at)
    |> Repo.all()
  end

  def get_monitor_log!(id), do: Repo.get!(MonitorLog, id)

  def find_nearest_technical_log(monitor_id, log) do
    from(l in MonitorLog,
      where: l.monitor_id == ^monitor_id,
      where: l.id != ^log.id,
      where: l.checked_at <= ^log.checked_at,
      where:
        fragment("? IS NOT NULL AND ? != '{}'::jsonb", l.response_headers, l.response_headers) or
          (not is_nil(l.response_snippet) and l.response_snippet != ""),
      order_by: [desc: l.checked_at],
      limit: 1
    )
    |> Repo.one()
  end

  def create_monitor_log(attrs \\ %{}) do
    case %MonitorLog{}
         |> MonitorLog.changeset(attrs)
         |> Repo.insert() do
      {:ok, log} ->
        Broadcaster.broadcast({:ok, log}, :log_created, log.monitor_id)
        {:ok, log}

      error ->
        error
    end
  end

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
