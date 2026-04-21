defmodule Holter.Delivery.ChannelLogs do
  @moduledoc false

  import Ecto.Query
  alias Holter.Delivery.NotificationChannelLog
  alias Holter.Monitoring.{DateFilter, Pagination}
  alias Holter.Repo

  @sortable_columns %{
    "dispatched_at" => :dispatched_at,
    "status" => :status
  }
  @valid_statuses MapSet.new(["success", "failed"])

  def list_channel_logs(channel, filters) do
    page_size = Pagination.resolve_page_size(filters[:page_size])
    base_query = build_base_query(channel.id, filters)

    {total_pages, current_page} = Pagination.calculate(base_query, page_size, filters[:page])

    logs =
      base_query
      |> apply_sort_order(filters[:sort_by], filters[:sort_dir])
      |> Pagination.paginate_query(current_page, page_size)
      |> Repo.all()

    %{
      logs: logs,
      page_number: current_page,
      total_pages: total_pages,
      page_size: page_size
    }
  end

  def get_channel_log!(id), do: Repo.get!(NotificationChannelLog, id)

  def create_channel_log(attrs \\ %{}) do
    %NotificationChannelLog{}
    |> NotificationChannelLog.changeset(attrs)
    |> Repo.insert()
  end

  defp build_base_query(channel_id, filters) do
    timezone = filters[:timezone] || "Etc/UTC"

    from(l in NotificationChannelLog,
      where: l.notification_channel_id == ^channel_id
    )
    |> apply_status_filter(filters[:status])
    |> apply_date_range_filter(
      %{start_date: filters[:start_date], end_date: filters[:end_date]},
      timezone
    )
  end

  defp apply_sort_order(query, sort_by, sort_dir) do
    field = Map.get(@sortable_columns, to_string(sort_by), :dispatched_at)
    dir = if sort_dir == "asc", do: :asc, else: :desc
    order_by(query, [l], [{^dir, field(l, ^field)}, desc: l.inserted_at])
  end

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
      {:ok, start_dt} -> where(query, [l], l.dispatched_at >= ^start_dt)
      _ -> query
    end
  end

  defp apply_date_range_filter(query, %{start_date: nil, end_date: end_date}, timezone) do
    case DateFilter.parse_to_datetime(end_date, :end, timezone) do
      {:ok, end_dt} -> where(query, [l], l.dispatched_at <= ^end_dt)
      _ -> query
    end
  end

  defp apply_date_range_filter(query, %{start_date: start_date, end_date: end_date}, timezone) do
    case {DateFilter.parse_to_datetime(start_date, :start, timezone),
          DateFilter.parse_to_datetime(end_date, :end, timezone)} do
      {{:ok, start_dt}, {:ok, end_dt}} ->
        where(query, [l], l.dispatched_at >= ^start_dt and l.dispatched_at <= ^end_dt)

      {{:ok, start_dt}, _} ->
        where(query, [l], l.dispatched_at >= ^start_dt)

      {_, {:ok, end_dt}} ->
        where(query, [l], l.dispatched_at <= ^end_dt)

      _ ->
        query
    end
  end
end
