defmodule Holter.Monitoring.Aggregator do
  @moduledoc """
  Service for aggregating monitoring data into daily metrics.
  """
  import Ecto.Query
  alias Holter.Repo
  alias Holter.Monitoring.{MonitorLog, Incident}

  @doc """
  Calculates and persists metrics for a monitor on a specific date.
  """
  def aggregate_monitor_date(monitor_id, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")

    avg_latency = calculate_avg_latency(monitor_id, start_of_day, end_of_day)
    downtime_seconds = calculate_downtime_seconds(monitor_id, start_of_day, end_of_day)

    total_minutes_in_day = 24 * 60
    downtime_minutes = round(downtime_seconds / 60)

    # Simple uptime: (Total - Downtime) / Total
    # For a full day: 1440 minutes
    uptime_percent =
      if downtime_minutes >= total_minutes_in_day do
        Decimal.new("0.00")
      else
        uptime = (total_minutes_in_day - downtime_minutes) / total_minutes_in_day * 100
        uptime |> Float.round(2) |> Decimal.from_float()
      end

    %{
      monitor_id: monitor_id,
      date: date,
      avg_latency_ms: avg_latency,
      total_downtime_minutes: downtime_minutes,
      uptime_percent: uptime_percent
    }
    |> Holter.Monitoring.upsert_daily_metric()
  end

  defp calculate_avg_latency(monitor_id, start_at, end_at) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> where([l], l.checked_at >= ^start_at and l.checked_at < ^end_at)
    |> select([l], avg(l.latency_ms))
    |> Repo.one()
    |> case do
      nil -> 0
      val -> val |> Decimal.to_integer()
    end
  end

  defp calculate_downtime_seconds(monitor_id, start_at, end_at) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> where([i], i.started_at < ^end_at)
    |> where([i], is_nil(i.resolved_at) or i.resolved_at > ^start_at)
    |> Repo.all()
    |> Enum.reduce(0, fn incident, acc ->
      overlap_start = max_datetime(incident.started_at, start_at)
      overlap_end = min_datetime(incident.resolved_at || DateTime.utc_now(), end_at)

      diff = DateTime.diff(overlap_end, overlap_start)
      acc + max(0, diff)
    end)
  end

  defp max_datetime(dt1, dt2) do
    if DateTime.compare(dt1, dt2) == :gt, do: dt1, else: dt2
  end

  defp min_datetime(dt1, dt2) do
    if DateTime.compare(dt1, dt2) == :lt, do: dt1, else: dt2
  end
end
