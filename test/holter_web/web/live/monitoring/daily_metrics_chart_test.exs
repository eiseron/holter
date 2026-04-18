defmodule HolterWeb.Web.Monitoring.DailyMetricsChartTest do
  use HolterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "Daily Metrics Chart on Daily Metrics page" do
    test "renders empty state when no metrics exist", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "#metrics-chart-#{monitor.id}")
      assert has_element?(lv, ".metrics-no-data")
    end

    test "renders metrics SVG when metrics exist", %{conn: conn} do
      monitor = monitor_fixture()

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: Date.utc_today(),
        uptime_percent: 99.5,
        avg_latency_ms: 120,
        total_downtime_minutes: 0
      })

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "#metrics-chart-#{monitor.id} .metrics-svg")
    end

    test "renders availability bars for each metric", %{conn: conn} do
      monitor = monitor_fixture()
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: today,
        uptime_percent: 100.0,
        avg_latency_ms: 80
      })

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: yesterday,
        uptime_percent: 95.0,
        avg_latency_ms: 200
      })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert html =~ "metrics-bar"
      assert html =~ "metrics-latency-line"
    end

    test "healthy bars use up color", %{conn: conn} do
      monitor = monitor_fixture()

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: Date.utc_today(),
        uptime_percent: 99.5,
        avg_latency_ms: 100
      })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert html =~ "--color-status-up"
    end

    test "unhealthy bars use down color", %{conn: conn} do
      monitor = monitor_fixture()

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: Date.utc_today(),
        uptime_percent: 95.0,
        avg_latency_ms: 500
      })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert html =~ "--color-status-down"
    end

    test "chart updates on metric_updated PubSub event", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")
      assert has_element?(lv, ".metrics-no-data")

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: Date.utc_today(),
        uptime_percent: 100.0,
        avg_latency_ms: 50
      })

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:monitor:#{monitor.id}",
        {:metric_updated, nil}
      )

      assert has_element?(lv, "#metrics-chart-#{monitor.id} .metrics-svg")
    end
  end
end
