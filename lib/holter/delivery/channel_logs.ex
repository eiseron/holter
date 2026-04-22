defmodule Holter.Delivery.ChannelLogs do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.{DateFilter, Pagination}
  alias Holter.Repo

  @delivery_workers [
    "Holter.Delivery.Workers.WebhookDispatcher",
    "Holter.Delivery.Workers.EmailDispatcher"
  ]
  @terminal_states ["completed", "discarded", "cancelled"]
  @sortable_columns %{"attempted_at" => :attempted_at, "state" => :state}

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

  def get_channel_log!(id), do: Repo.get!(Oban.Job, id)

  def classify_delivery_status(%Oban.Job{state: "completed"}), do: "success"
  def classify_delivery_status(%Oban.Job{}), do: "failed"

  def format_event_type(%Oban.Job{args: %{"test" => true}}), do: "test"
  def format_event_type(%Oban.Job{args: %{"event" => event}}), do: event

  def format_last_error(%Oban.Job{errors: []}), do: nil
  def format_last_error(%Oban.Job{errors: errors}), do: errors |> List.last() |> Map.get("error")

  defp build_base_query(channel_id, filters) do
    timezone = filters[:timezone] || "Etc/UTC"

    from(j in Oban.Job,
      where: j.worker in ^@delivery_workers,
      where: j.state in ^@terminal_states,
      where: fragment("? @> jsonb_build_object('channel_id', ?::text)", j.args, ^channel_id)
    )
    |> apply_status_filter(filters[:status])
    |> apply_date_range_filter(
      %{start_date: filters[:start_date], end_date: filters[:end_date]},
      timezone
    )
  end

  defp apply_sort_order(query, sort_by, sort_dir) do
    field = Map.get(@sortable_columns, to_string(sort_by), :attempted_at)
    dir = if sort_dir == "asc", do: :asc, else: :desc
    order_by(query, [j], [{^dir, field(j, ^field)}, desc: j.id])
  end

  defp apply_status_filter(query, nil), do: query
  defp apply_status_filter(query, ""), do: query
  defp apply_status_filter(query, "success"), do: where(query, [j], j.state == "completed")
  defp apply_status_filter(query, "failed"), do: where(query, [j], j.state != "completed")
  defp apply_status_filter(query, _), do: query

  defp apply_date_range_filter(query, %{start_date: nil, end_date: nil}, _timezone), do: query

  defp apply_date_range_filter(query, %{start_date: start_date, end_date: nil}, timezone) do
    case DateFilter.parse_to_datetime(start_date, :start, timezone) do
      {:ok, start_dt} -> where(query, [j], j.attempted_at >= ^start_dt)
      _ -> query
    end
  end

  defp apply_date_range_filter(query, %{start_date: nil, end_date: end_date}, timezone) do
    case DateFilter.parse_to_datetime(end_date, :end, timezone) do
      {:ok, end_dt} -> where(query, [j], j.attempted_at <= ^end_dt)
      _ -> query
    end
  end

  defp apply_date_range_filter(query, %{start_date: start_date, end_date: end_date}, timezone) do
    case {DateFilter.parse_to_datetime(start_date, :start, timezone),
          DateFilter.parse_to_datetime(end_date, :end, timezone)} do
      {{:ok, start_dt}, {:ok, end_dt}} ->
        where(query, [j], j.attempted_at >= ^start_dt and j.attempted_at <= ^end_dt)

      {{:ok, start_dt}, _} ->
        where(query, [j], j.attempted_at >= ^start_dt)

      {_, {:ok, end_dt}} ->
        where(query, [j], j.attempted_at <= ^end_dt)

      _ ->
        query
    end
  end
end
