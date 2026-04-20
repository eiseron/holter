defmodule Holter.Monitoring.Aggregator do
  @moduledoc """
  Service for aggregating monitoring data into daily metrics.
  """
  import Ecto.Query
  alias Holter.Monitoring.{Incident, MonitorLog}
  alias Holter.Repo

  def aggregate_monitor_date(monitor_id, date) do
    monitor = Holter.Monitoring.get_monitor!(monitor_id)
    now = DateTime.utc_now()
    time_range = build_day_range(date, monitor, now)

    if has_activity?(monitor_id, time_range) do
      data = fetch_aggregation_data(monitor_id, time_range, now)
      build_metrics(monitor, date, data)
    else
      build_empty_metrics(monitor_id, date)
    end
    |> Holter.Monitoring.upsert_daily_metric()
  end

  defp has_activity?(monitor_id, time_range) do
    count_logs(monitor_id, time_range) > 0 or incidents_exist?(monitor_id, time_range)
  end

  defp fetch_aggregation_data(monitor_id, {start_at, end_at} = time_range, now) do
    %{
      time_range: time_range,
      now: now,
      avg_latency_ms: fetch_avg_latency(monitor_id, time_range),
      incidents: fetch_overlapping_incidents(monitor_id, start_at, end_at)
    }
  end

  defp build_metrics(monitor, date, data) do
    downtime_seconds = calculate_downtime_seconds_from(data.incidents, data.time_range, data.now)

    %{
      monitor_id: monitor.id,
      date: date,
      avg_latency_ms: data.avg_latency_ms,
      total_downtime_minutes: seconds_to_minutes(downtime_seconds),
      uptime_percent: compute_uptime(downtime_seconds, data.time_range)
    }
  end

  defp build_empty_metrics(monitor_id, date) do
    %{
      monitor_id: monitor_id,
      date: date,
      avg_latency_ms: 0,
      total_downtime_minutes: 0,
      uptime_percent: Decimal.from_float(0.0)
    }
  end

  defp build_day_range(date, monitor, now) do
    day_start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    day_end = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")

    start_at = max_datetime(day_start, monitor.inserted_at)
    end_at = min_datetime(day_end, now)

    {start_at, end_at}
  end

  defp count_logs(monitor_id, {start_at, end_at}) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> where([l], l.checked_at >= ^start_at and l.checked_at < ^end_at)
    |> Repo.aggregate(:count, :id)
  end

  defp incidents_exist?(monitor_id, {start_at, end_at}) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> where([i], i.started_at < ^end_at)
    |> where([i], is_nil(i.resolved_at) or i.resolved_at > ^start_at)
    |> Repo.exists?()
  end

  defp fetch_avg_latency(monitor_id, {start_at, end_at}) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> where([l], l.checked_at >= ^start_at and l.checked_at < ^end_at)
    |> where([l], l.status == :up)
    |> select([l], avg(l.latency_ms))
    |> Repo.one()
    |> normalize_latency()
  end

  defp normalize_latency(nil), do: 0
  defp normalize_latency(val), do: val |> Decimal.round(0) |> Decimal.to_integer()

  defp fetch_overlapping_incidents(monitor_id, start_at, end_at) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> where([i], i.started_at < ^end_at)
    |> where([i], is_nil(i.resolved_at) or i.resolved_at > ^start_at)
    |> Repo.all()
  end

  defp calculate_downtime_seconds_from(incidents, {_start_at, _end_at} = time_range, now) do
    incidents
    |> Enum.map(&calculate_incident_overlap_seconds(&1, time_range, now))
    |> Enum.sum()
  end

  defp compute_uptime(downtime_seconds, {start_at, end_at}) do
    total_seconds = DateTime.diff(end_at, start_at)

    downtime_seconds
    |> compute_uptime_ratio(total_seconds)
    |> to_percentage_decimal()
  end

  defp seconds_to_minutes(seconds), do: round(seconds / 60)

  defp compute_uptime_ratio(downtime, total) when downtime >= total, do: 0.0
  defp compute_uptime_ratio(downtime, total), do: (total - downtime) / total

  defp to_percentage_decimal(ratio) do
    (ratio * 100)
    |> Float.round(2)
    |> Decimal.from_float()
  end

  defp calculate_incident_overlap_seconds(incident, {range_start, range_end}, now) do
    overlap_start = max_datetime(incident.started_at, range_start)
    overlap_end = min_datetime(incident.resolved_at || now, range_end)

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
