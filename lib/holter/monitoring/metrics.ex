defmodule Holter.Monitoring.Metrics do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.{Broadcaster, DailyMetric, Pagination}
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

    {total_pages, current_page} = Pagination.calculate(base_query, page_size, filters[:page])

    metrics =
      base_query
      |> apply_sort_order(filters[:sort_by], filters[:sort_dir])
      |> Pagination.paginate_query(current_page, page_size)
      |> Repo.all()

    %{
      metrics: metrics,
      page_number: current_page,
      total_pages: total_pages,
      page_size: page_size
    }
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
        Broadcaster.broadcast({:ok, metric}, :metric_updated, metric.monitor_id)
        {:ok, metric}

      error ->
        error
    end
  end

  defp apply_sort_order(query, sort_by, sort_dir) do
    field = Map.get(@sortable_columns, to_string(sort_by || "date"), :date)
    dir = if sort_dir == "asc", do: :asc, else: :desc
    order_by(query, [m], [{^dir, field(m, ^field)}, desc: m.inserted_at])
  end
end
