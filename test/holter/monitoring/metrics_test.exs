defmodule Holter.Monitoring.MetricsTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring.Metrics

  setup do
    monitor = monitor_fixture()
    %{monitor: monitor}
  end

  describe "list_daily_metrics/2 — pagination" do
    test "returns page 1 by default", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01]})
      result = Metrics.list_daily_metrics(monitor.id)
      assert result.page_number == 1
    end

    test "total_pages is 1 when metrics fit in one page", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01]})
      result = Metrics.list_daily_metrics(monitor.id, %{page_size: 30})
      assert result.total_pages == 1
    end

    test "clamps page to 1 when requested page is 0", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01]})
      result = Metrics.list_daily_metrics(monitor.id, %{page: 0})
      assert result.page_number == 1
    end

    test "clamps page to total_pages when requested page exceeds total", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01]})
      result = Metrics.list_daily_metrics(monitor.id, %{page: 9999, page_size: 30})
      assert result.page_number == result.total_pages
    end

    test "respects page_size", %{monitor: monitor} do
      for day <- 1..5 do
        daily_metric_fixture(%{monitor_id: monitor.id, date: Date.new!(2026, 1, day)})
      end

      result = Metrics.list_daily_metrics(monitor.id, %{page_size: 2})
      assert length(result.metrics) == 2
    end

    test "returns empty list for monitor with no metrics", %{monitor: monitor} do
      result = Metrics.list_daily_metrics(monitor.id)
      assert result.metrics == []
    end
  end

  describe "list_daily_metrics/2 — sorting" do
    test "sorts by date desc by default", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01]})
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-03]})

      result = Metrics.list_daily_metrics(monitor.id)
      assert List.first(result.metrics).date == ~D[2026-01-03]
    end

    test "sorts by date asc when requested", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-03]})
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01]})

      result = Metrics.list_daily_metrics(monitor.id, %{sort_by: "date", sort_dir: "asc"})
      assert List.first(result.metrics).date == ~D[2026-01-01]
    end

    test "sorts by uptime_percent asc when requested", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01], uptime_percent: 90.0})
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-02], uptime_percent: 99.0})

      result =
        Metrics.list_daily_metrics(monitor.id, %{sort_by: "uptime_percent", sort_dir: "asc"})

      first_uptime =
        result.metrics |> List.first() |> Map.get(:uptime_percent) |> Decimal.to_float()

      assert first_uptime < 95.0
    end

    test "sorts by avg_latency_ms desc when requested", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01], avg_latency_ms: 100})
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-02], avg_latency_ms: 500})

      result =
        Metrics.list_daily_metrics(monitor.id, %{sort_by: "avg_latency_ms", sort_dir: "desc"})

      assert List.first(result.metrics).avg_latency_ms == 500
    end

    test "falls back to date desc for unrecognised sort_by", %{monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-01]})
      daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-03]})

      result = Metrics.list_daily_metrics(monitor.id, %{sort_by: "not_a_column"})
      assert List.first(result.metrics).date == ~D[2026-01-03]
    end
  end

  describe "get_daily_metric/2" do
    test "returns the metric for the given monitor and date", %{monitor: monitor} do
      metric = daily_metric_fixture(%{monitor_id: monitor.id, date: ~D[2026-01-15]})

      found = Metrics.get_daily_metric(monitor.id, ~D[2026-01-15])
      assert found.id == metric.id
    end

    test "returns nil when no metric exists for that date", %{monitor: monitor} do
      assert Metrics.get_daily_metric(monitor.id, ~D[2026-01-15]) == nil
    end

    test "does not return a metric for a different monitor" do
      other_monitor = monitor_fixture()
      daily_metric_fixture(%{monitor_id: other_monitor.id, date: ~D[2026-01-15]})

      monitor = monitor_fixture()
      assert Metrics.get_daily_metric(monitor.id, ~D[2026-01-15]) == nil
    end
  end

  describe "upsert_daily_metric/1" do
    test "inserts a new metric when none exists", %{monitor: monitor} do
      {:ok, metric} =
        Metrics.upsert_daily_metric(%{
          monitor_id: monitor.id,
          date: ~D[2026-01-15],
          uptime_percent: 99.5,
          avg_latency_ms: 100,
          total_downtime_minutes: 0
        })

      assert metric.uptime_percent == Decimal.new("99.5")
    end

    test "updates an existing metric on conflict (same monitor + date)", %{monitor: monitor} do
      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: ~D[2026-01-15],
        uptime_percent: 90.0,
        avg_latency_ms: 200
      })

      {:ok, updated} =
        Metrics.upsert_daily_metric(%{
          monitor_id: monitor.id,
          date: ~D[2026-01-15],
          uptime_percent: 99.5,
          avg_latency_ms: 100,
          total_downtime_minutes: 0
        })

      assert Decimal.compare(updated.uptime_percent, Decimal.new("99.5")) == :eq
      assert updated.avg_latency_ms == 100
    end

    test "does not create a duplicate row when the same monitor+date conflicts", %{
      monitor: monitor
    } do
      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: ~D[2026-01-15],
        uptime_percent: 90.0,
        avg_latency_ms: 200,
        total_downtime_minutes: 0
      })

      {:ok, _} =
        Metrics.upsert_daily_metric(%{
          monitor_id: monitor.id,
          date: ~D[2026-01-15],
          uptime_percent: 99.5,
          avg_latency_ms: 100,
          total_downtime_minutes: 0
        })

      assert length(Metrics.list_daily_metrics(monitor.id).metrics) == 1
    end
  end
end
