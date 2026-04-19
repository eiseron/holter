defmodule HolterWeb.Web.Monitoring.MonitorOverviewChartTest do
  use HolterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "Monitor Overview Chart on Show page" do
    test "renders empty state when no logs exist in last 24h", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert has_element?(lv, "#ovw-chart-#{monitor.id}")
      assert has_element?(lv, ".ovw-no-data")
    end

    test "renders SVG area chart when recent logs exist", %{conn: conn} do
      monitor = monitor_fixture()

      log_fixture(%{
        monitor_id: monitor.id,
        status: :up,
        latency_ms: 120,
        checked_at: DateTime.utc_now()
      })

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert has_element?(lv, "#ovw-chart-#{monitor.id} .ovw-area-svg")
      assert has_element?(lv, "#ovw-chart-#{monitor.id} .ovw-ribbon-svg")
    end

    test "renders area path when logs have latency data", %{conn: conn} do
      monitor = monitor_fixture()

      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 200})
      log_fixture(%{monitor_id: monitor.id, status: :down, latency_ms: 500})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "ovw-area-line"
    end

    test "status ribbon uses down color for failed checks", %{conn: conn} do
      monitor = monitor_fixture()

      log_fixture(%{monitor_id: monitor.id, status: :down, latency_ms: 800})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "--color-status-down"
    end

    test "renders dynamic X-axis time labels and vertical grid lines", %{conn: conn} do
      monitor = monitor_fixture()
      now = DateTime.utc_now()
      one_hour_ago = DateTime.add(now, -1, :hour)

      log_fixture(%{monitor_id: monitor.id, status: :up, checked_at: one_hour_ago})
      log_fixture(%{monitor_id: monitor.id, status: :up, checked_at: now})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "chart-grid-line"
      assert html =~ "chart-scale-label"

      assert html =~ ~r/\d{2}:\d{2}/
    end

    test "scales horizontal grid lines based on max latency", %{conn: conn} do
      monitor = monitor_fixture()

      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 100})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert html =~ "100ms"
      assert html =~ "50ms"

      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 1000})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert html =~ "1000ms"
      assert html =~ "500ms"
    end

    test "updates chart when a new log_created event arrives via PubSub", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert has_element?(lv, ".ovw-no-data")

      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 150})

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:monitor:#{monitor.id}",
        {:log_created, nil}
      )

      assert has_element?(lv, "#ovw-chart-#{monitor.id} .ovw-area-svg")
    end
  end
end
