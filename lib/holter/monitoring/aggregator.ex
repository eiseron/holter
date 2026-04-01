defmodule Holter.Monitoring.Aggregator do
  @moduledoc """
  Service for aggregating monitoring data into daily metrics.
  """
  import Ecto.Query
  alias Holter.Repo
  alias Holter.Monitoring.{MonitorLog, Incident}

  def aggregate_monitor_date(monitor_id, date) do
    time_range = build_day_range(date)

    %{
      monitor_id: monitor_id,
      date: date,
      avg_latency_ms: fetch_avg_latency(monitor_id, time_range),
      total_downtime_minutes: calculate_total_downtime_minutes(monitor_id, time_range),
      uptime_percent: calculate_uptime_percent(monitor_id, time_range)
    }
    |> Holter.Monitoring.upsert_daily_metric()
  end

  defp build_day_range(date) do
    start_at = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_at = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")
    {start_at, end_at}
  end

  defp fetch_avg_latency(monitor_id, {start_at, end_at}) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> where([l], l.checked_at >= ^start_at and l.checked_at < ^end_at)
    |> select([l], avg(l.latency_ms))
    |> Repo.one()
    |> normalize_latency()
  end

  defp normalize_latency(nil), do: 0
  defp normalize_latency(val), do: Decimal.to_integer(val)

  defp calculate_total_downtime_minutes(monitor_id, time_range) do
    monitor_id
    |> calculate_downtime_seconds(time_range)
    |> seconds_to_minutes()
  end

  defp seconds_to_minutes(seconds), do: round(seconds / 60)

  defp calculate_uptime_percent(monitor_id, time_range) do
    downtime_seconds = calculate_downtime_seconds(monitor_id, time_range)
    total_seconds = 24 * 60 * 60

    downtime_seconds
    |> compute_uptime_ratio(total_seconds)
    |> to_percentage_decimal()
  end

  defp compute_uptime_ratio(downtime, total) when downtime >= total, do: 0.0
  defp compute_uptime_ratio(downtime, total), do: (total - downtime) / total

  defp to_percentage_decimal(ratio) do
    (ratio * 100)
    |> Float.round(2)
    |> Decimal.from_float()
  end

  defp calculate_downtime_seconds(monitor_id, {start_at, end_at}) do
    monitor_id
    |> fetch_overlapping_incidents(start_at, end_at)
    |> Enum.map(&calculate_incident_overlap_seconds(&1, start_at, end_at))
    |> Enum.sum()
  end

  defp fetch_overlapping_incidents(monitor_id, start_at, end_at) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> where([i], i.started_at < ^end_at)
    |> where([i], is_nil(i.resolved_at) or i.resolved_at > ^start_at)
    |> Repo.all()
  end

  defp calculate_incident_overlap_seconds(incident, range_start, range_end) do
    overlap_start = max_datetime(incident.started_at, range_start)
    overlap_end = min_datetime(incident.resolved_at || DateTime.utc_now(), range_end)

    overlap_end
    |> DateTime.diff(overlap_start)
    |> max(0)
  end

  defp max_datetime(dt1, dt2) do
    if DateTime.compare(dt1, dt2) == :gt, do: dt1, else: dt2
  end

  defp min_datetime(dt1, dt2) do
    if DateTime.compare(dt1, dt2) == :lt, do: dt1, else: dt2
  end
end
