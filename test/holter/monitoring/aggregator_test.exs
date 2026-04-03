defmodule Holter.Monitoring.AggregatorTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring
  alias Holter.Monitoring.Aggregator

  describe "aggregate_monitor_date/2" do
    setup do
      {:ok, monitor} =
        Monitoring.create_monitor(%{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30
        })

      %{monitor: monitor}
    end

    test "aggregates metrics for a day with success and failure", %{monitor: monitor} do
      date = ~D[2026-04-01]
      start_of_day = DateTime.new!(date, ~T[10:00:00], "Etc/UTC")

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        latency_ms: 100,
        checked_at: start_of_day
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        latency_ms: 200,
        checked_at: DateTime.add(start_of_day, 3600)
      })

      incident_start = DateTime.new!(date, ~T[12:00:00], "Etc/UTC")

      {:ok, incident} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :downtime,
          started_at: incident_start
        })

      Monitoring.resolve_incident(incident, DateTime.add(incident_start, 600))

      {:ok, metric} = Aggregator.aggregate_monitor_date(monitor.id, date)

      assert metric.date == date
      assert metric.avg_latency_ms == 150
      assert metric.total_downtime_minutes == 10
      assert Decimal.to_float(metric.uptime_percent) == 99.31
    end

    test "handles incidents spanning multiple days", %{monitor: monitor} do
      day1 = ~D[2026-04-01]
      day2 = ~D[2026-04-02]

      incident_start = DateTime.new!(day1, ~T[23:50:00], "Etc/UTC")

      {:ok, incident} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :downtime,
          started_at: incident_start
        })

      Monitoring.resolve_incident(incident, DateTime.add(incident_start, 1200))

      {:ok, metric1} = Aggregator.aggregate_monitor_date(monitor.id, day1)
      {:ok, metric2} = Aggregator.aggregate_monitor_date(monitor.id, day2)

      assert metric1.total_downtime_minutes == 10
      assert metric2.total_downtime_minutes == 10
    end

    test "upserts existing metrics", %{monitor: monitor} do
      date = ~D[2026-04-01]

      Aggregator.aggregate_monitor_date(monitor.id, date)
      {:ok, _metric} = Aggregator.aggregate_monitor_date(monitor.id, date)

      assert Repo.aggregate(Holter.Monitoring.DailyMetric, :count, :id) == 1
    end
  end
end
