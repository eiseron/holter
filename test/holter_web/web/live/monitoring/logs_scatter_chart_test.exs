defmodule HolterWeb.Web.Monitoring.LogsScatterChartTest do
  use HolterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "Logs Scatter Chart on Technical Logs page" do
    test "renders empty state when no logs exist", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      assert has_element?(lv, "#scatter-chart-#{monitor.id}")
      assert has_element?(lv, ".scatter-no-data")
    end

    test "renders scatter SVG when logs exist", %{conn: conn} do
      monitor = monitor_fixture()
      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 120})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      assert has_element?(lv, "#scatter-chart-#{monitor.id} .scatter-svg")
    end

    test "renders trend line and dots when multiple logs exist", %{conn: conn} do
      monitor = monitor_fixture()
      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 100})
      log_fixture(%{monitor_id: monitor.id, status: :down, latency_ms: 600})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      assert html =~ "scatter-trend-line"
      assert html =~ "scatter-dot"
    end

    test "uses down color for failed log markers", %{conn: conn} do
      monitor = monitor_fixture()
      log_fixture(%{monitor_id: monitor.id, status: :down, latency_ms: 800})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      assert html =~ "--color-status-down"
    end

    test "uses up color for healthy log markers", %{conn: conn} do
      monitor = monitor_fixture()
      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 100})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      assert html =~ "--color-status-up"
    end

    test "chart updates after filter change", %{conn: conn} do
      monitor = monitor_fixture()
      log_fixture(%{monitor_id: monitor.id, status: :down, latency_ms: 500})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")
      assert has_element?(lv, ".scatter-svg")

      lv
      |> form("form", filters: %{status: "up"})
      |> render_change()

      assert has_element?(lv, ".scatter-no-data")
    end
  end
end
