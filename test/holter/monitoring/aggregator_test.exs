defmodule Holter.Monitoring.AggregatorTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring
  alias Holter.Monitoring.Aggregator

  describe "aggregate_monitor_date/2" do
    defp create_monitor(workspace, inserted_at) do
      {:ok, monitor} =
        Monitoring.create_monitor(%{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30,
          workspace_id: workspace.id
        })

      if inserted_at do
        Repo.query!("UPDATE monitors SET inserted_at = $1 WHERE id = $2", [
          inserted_at,
          Ecto.UUID.dump!(monitor.id)
        ])

        Monitoring.get_monitor!(monitor.id)
      else
        monitor
      end
    end

    setup do
      workspace = workspace_fixture()
      monitor = create_monitor(workspace, DateTime.new!(~D[2026-01-01], ~T[00:00:00], "Etc/UTC"))
      %{monitor: monitor, workspace: workspace}
    end

    test "aggregates metrics for a day with success and failure", %{monitor: monitor} do
      date = ~D[2026-04-01]
      start_of_day = DateTime.new!(date, ~T[10:00:00], "Etc/UTC")

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        latency_ms: 100,
        checked_at: start_of_day
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
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

    test "uses dynamic window for monitors created mid-day", %{workspace: workspace} do
      date = ~D[2026-04-01]
      inserted_at = DateTime.new!(date, ~T[12:00:00], "Etc/UTC")
      monitor = create_monitor(workspace, inserted_at)

      incident_start = DateTime.new!(date, ~T[13:00:00], "Etc/UTC")

      {:ok, incident} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :downtime,
          started_at: incident_start
        })

      Monitoring.resolve_incident(incident, DateTime.add(incident_start, 600))

      {:ok, metric} = Aggregator.aggregate_monitor_date(monitor.id, date)

      assert Decimal.to_float(metric.uptime_percent) == 98.61
    end

    test "filters latency to only include successful checks", %{monitor: monitor} do
      date = ~D[2026-04-01]

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        latency_ms: 100,
        checked_at: DateTime.new!(date, ~T[10:00:00], "Etc/UTC")
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        latency_ms: 101,
        checked_at: DateTime.new!(date, ~T[10:01:00], "Etc/UTC")
      })

      {:ok, metric} = Aggregator.aggregate_monitor_date(monitor.id, date)

      assert metric.avg_latency_ms in [100, 101]
    end

    test "handles 'unknown' state when no logs exist for the day", %{monitor: monitor} do
      date = ~D[2026-04-01]

      {:ok, metric} = Aggregator.aggregate_monitor_date(monitor.id, date)

      assert metric.avg_latency_ms == 0
      assert Decimal.to_float(metric.uptime_percent) == 0.0
    end
  end
end
