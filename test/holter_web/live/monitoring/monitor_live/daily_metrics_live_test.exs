defmodule HolterWeb.Web.Monitoring.MonitorLive.DailyMetricsTest do
  use HolterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "mount" do
    test "renders metrics table when metrics exist", %{conn: conn} do
      monitor = monitor_fixture()
      today = Date.utc_today()

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: today,
        uptime_percent: 99.5,
        avg_latency_ms: 120,
        total_downtime_minutes: 3
      })

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "#metrics-table")
      assert has_element?(lv, "td", Calendar.strftime(today, "%Y-%m-%d"))
      assert has_element?(lv, "td", "120ms")
    end

    test "renders empty state when no metrics exist", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, ".h-empty-state")
    end

    test "renders monitor url in subtitle", %{conn: conn} do
      monitor = monitor_fixture(%{url: "https://example.com"})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, ".h-text-muted.h-font-mono", monitor.url)
    end

    test "back link points to monitor show screen", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "a[href='/monitoring/monitor/#{monitor.id}']")
    end

    test "technical logs link is present", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "a[href='/monitoring/monitor/#{monitor.id}/logs']")
    end
  end

  describe "sorting" do
    test "sorts by date ascending when sort_by=date&sort_dir=asc", %{conn: conn} do
      monitor = monitor_fixture()
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      daily_metric_fixture(%{monitor_id: monitor.id, date: today, avg_latency_ms: 100})
      daily_metric_fixture(%{monitor_id: monitor.id, date: yesterday, avg_latency_ms: 200})

      {:ok, lv, _html} =
        live(
          conn,
          ~p"/monitoring/monitor/#{monitor.id}/daily_metrics?sort_by=date&sort_dir=asc"
        )

      html = render(lv)
      pos_yesterday = :binary.match(html, Calendar.strftime(yesterday, "%Y-%m-%d")) |> elem(0)
      pos_today = :binary.match(html, Calendar.strftime(today, "%Y-%m-%d")) |> elem(0)
      assert pos_yesterday < pos_today
    end

    test "date column header link contains sort params", %{conn: conn} do
      monitor = monitor_fixture()
      daily_metric_fixture(%{monitor_id: monitor.id, date: Date.utc_today()})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "a[href*='sort_by=date']")
    end

    test "uptime_percent column header link contains sort params", %{conn: conn} do
      monitor = monitor_fixture()
      daily_metric_fixture(%{monitor_id: monitor.id, date: Date.utc_today()})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "a[href*='sort_by=uptime_percent']")
    end
  end

  describe "pagination" do
    test "renders pagination nav", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "[data-role='page-info']")
    end

    test "shows page 1 of 1 when few metrics exist", %{conn: conn} do
      monitor = monitor_fixture()
      daily_metric_fixture(%{monitor_id: monitor.id, date: Date.utc_today()})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, "[data-role='page-info']", "Page 1 of 1")
    end
  end

  describe "real-time updates" do
    test "refreshes metrics on log_created event", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, ".h-empty-state")

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: Date.utc_today(),
        uptime_percent: 100.0,
        avg_latency_ms: 50,
        total_downtime_minutes: 0
      })

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:monitor:#{monitor.id}",
        {:log_created, nil}
      )

      assert has_element?(lv, "#metrics-table")
    end

    test "refreshes metrics on metric_updated event", %{conn: conn} do
      monitor = monitor_fixture()

      {:ok, lv, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert has_element?(lv, ".h-empty-state")

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: Date.utc_today(),
        uptime_percent: 99.0,
        avg_latency_ms: 80,
        total_downtime_minutes: 1
      })

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:monitor:#{monitor.id}",
        {:metric_updated, nil}
      )

      assert has_element?(lv, "#metrics-table")
    end
  end
end
