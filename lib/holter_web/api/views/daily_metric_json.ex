defmodule HolterWeb.Api.DailyMetricJSON do
  @moduledoc """
  JSON view for rendering daily metric data.
  """
  alias Holter.Monitoring.DailyMetric

  def index(%{
        result: %{
          metrics: metrics,
          page_number: page,
          total_pages: total_pages,
          page_size: page_size
        }
      }) do
    %{
      data: for(metric <- metrics, do: data(metric)),
      meta: %{page: page, page_size: page_size, total_pages: total_pages}
    }
  end

  defp data(%DailyMetric{} = metric) do
    %{
      id: metric.id,
      date: metric.date,
      uptime_percent: metric.uptime_percent,
      avg_latency_ms: metric.avg_latency_ms,
      total_downtime_minutes: metric.total_downtime_minutes,
      inserted_at: metric.inserted_at,
      updated_at: metric.updated_at
    }
  end
end
