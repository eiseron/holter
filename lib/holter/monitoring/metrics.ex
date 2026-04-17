defmodule Holter.Monitoring.Metrics do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.DailyMetric
  alias Holter.Repo

  @sortable_columns %{
    "date" => :date,
    "uptime_percent" => :uptime_percent,
    "avg_latency_ms" => :avg_latency_ms,
    "total_downtime_minutes" => :total_downtime_minutes
  }

  @default_page_size 30

  def list_daily_metrics(monitor_id, filters \\ %{}) do
    page_size = filters[:page_size] || @default_page_size
    base_query = from(m in DailyMetric, where: m.monitor_id == ^monitor_id)

    {total_pages, current_page} = calculate_pagination(base_query, page_size, filters[:page])

    metrics =
      base_query
      |> apply_sort_order(filters[:sort_by], filters[:sort_dir])
      |> limit(^page_size)
      |> offset(^((current_page - 1) * page_size))
      |> Repo.all()

    %{
      metrics: metrics,
      page_number: current_page,
      total_pages: total_pages,
      page_size: page_size
    }
  end

  defp calculate_pagination(query, page_size, requested_page) do
    total_count = Repo.one(from(m in query, select: count(m.id)))
    total_pages = ceil(total_count / page_size) |> max(1)

    current_page =
      (requested_page || 1)
      |> min(total_pages)
      |> max(1)

    {total_pages, current_page}
  end

  defp apply_sort_order(query, sort_by, sort_dir) do
    field = Map.get(@sortable_columns, to_string(sort_by || "date"), :date)
    dir = if sort_dir == "asc", do: :asc, else: :desc
    order_by(query, [m], [{^dir, field(m, ^field)}, desc: m.inserted_at])
  end

  def get_daily_metric(monitor_id, date) do
    Repo.get_by(DailyMetric, monitor_id: monitor_id, date: date)
  end

  def upsert_daily_metric(attrs) do
    case %DailyMetric{}
         |> DailyMetric.changeset(attrs)
         |> Repo.insert(
           on_conflict: {:replace_all_except, [:id, :monitor_id, :date, :inserted_at]},
           conflict_target: [:monitor_id, :date]
         ) do
      {:ok, metric} ->
        broadcast({:ok, metric}, :metric_updated)
        {:ok, metric}

      error ->
        error
    end
  end

  defp broadcast({:ok, metric}, event) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "monitoring:monitor:#{metric.monitor_id}",
      {event, metric}
    )

    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitors", {event, metric})
    {:ok, metric}
  end

  defp broadcast(error, _), do: error
end
