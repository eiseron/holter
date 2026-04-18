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
