defmodule HolterWeb.Web.Monitoring.MonitorLiveLogsTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Holter.Monitoring

  @monitor_attrs %{
    url: "https://example.local",
    method: :get,
    interval_seconds: 60,
    logical_state: :active
  }

  setup do
    monitor = monitor_fixture(@monitor_attrs)
    workspace = Monitoring.get_workspace!(monitor.workspace_id)
    %{monitor: monitor, workspace: workspace}
  end

  describe "technical logs page basics" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 123})

      {:ok, view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs?page=1")

      %{view: view, html: html}
    end

    test "it displays the monitor URL and technical context", %{html: html} do
      assert html =~ "data-role=\"page-title\""
      assert html =~ "https://example.local"
      assert html =~ "data-role=\"log-status\""
      assert html =~ "data-status=\"up\""
      assert html =~ "123ms"
    end
  end

  describe "filtering and combined states" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      today = ~U[2026-04-08 10:00:00Z]
      yesterday = ~U[2026-04-07 10:00:00Z]

      log_fixture(%{monitor_id: monitor.id, status: :up, checked_at: today})
      log_fixture(%{monitor_id: monitor.id, status: :up, checked_at: yesterday})

      log_fixture(%{monitor_id: monitor.id, status: :down, checked_at: today})
      log_fixture(%{monitor_id: monitor.id, status: :down, checked_at: yesterday})

      %{conn: conn, monitor: monitor, workspace: workspace}
    end

    test "filters by combined status and date range", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      url =
        ~p"/monitoring/monitor/#{monitor.id}/logs?status=down&start_date=2026-04-08&page=1"

      {:ok, _view, html} = live(conn, url)

      assert html =~ "data-status=\"down\""
      assert html =~ "2026-04-08"

      refute html =~ "data-status=\"up\""
      refute html =~ "2026-04-07"
    end

    test "renders empty state when no logs match filters", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      url =
        ~p"/monitoring/monitor/#{monitor.id}/logs?status=compromised&page=1"

      {:ok, _view, html} = live(conn, url)

      assert html =~ "data-role=\"page-info\""
      refute html =~ "data-role=\"log-status\""
    end
  end

  describe "advanced pagination logic" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      for i <- 1..12 do
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          checked_at: DateTime.add(~U[2026-04-08 00:00:00Z], i, :minute)
        })
      end

      %{conn: conn, monitor: monitor, workspace: workspace}
    end

    test "clicking page number preserves existing filters", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      url =
        ~p"/monitoring/monitor/#{monitor.id}/logs?status=up&page_size=5&page=1"

      {:ok, view, _html} = live(conn, url)

      view |> element("a", "2") |> render_click()

      assert_patch(
        view,
        ~p"/monitoring/monitor/#{monitor.id}/logs?page=2&page_size=5&sort_by=checked_at&sort_dir=desc&status=up"
      )
    end

    test "handles out of bounds page numbers by resetting to last valid page", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      url =
        ~p"/monitoring/monitor/#{monitor.id}/logs?page=10&page_size=5"

      {:ok, view, _html} = live(conn, url)

      page_info = view |> element("[data-role='page-info']") |> render()
      assert page_info =~ "3"
    end

    test "updating filter resets to page 1", %{conn: conn, monitor: monitor, workspace: workspace} do
      url =
        ~p"/monitoring/monitor/#{monitor.id}/logs?page=2&page_size=5"

      {:ok, view, _html} = live(conn, url)

      view
      |> form("form[phx-change=\"filter_updated\"]")
      |> render_change(%{filters: %{status: "down", page_size: "5"}})

      assert_patch(
        view,
        ~p"/monitoring/monitor/#{monitor.id}/logs?page_size=5&sort_by=checked_at&sort_dir=desc&status=down"
      )
    end
  end

  describe "log table column sorting" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      slow =
        log_fixture(%{
          monitor_id: monitor.id,
          latency_ms: 900,
          checked_at: ~U[2026-04-01 10:00:00Z]
        })

      fast =
        log_fixture(%{
          monitor_id: monitor.id,
          latency_ms: 50,
          checked_at: ~U[2026-04-10 10:00:00Z]
        })

      %{conn: conn, monitor: monitor, workspace: workspace, slow: slow, fast: fast}
    end

    test "default page renders Time header as sort link with no active indicator", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      assert html =~ "h-table-sort-header"
      assert html =~ "sort_by=checked_at"
    end

    test "sort_by=checked_at&sort_dir=asc returns oldest log first (oldest appears before newest)",
         %{
           conn: conn,
           monitor: monitor,
           workspace: workspace
         } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/monitoring/monitor/#{monitor.id}/logs?sort_by=checked_at&sort_dir=asc"
        )

      html = render(view)
      first_row_pos = :binary.match(html, "2026-04-01")
      second_row_pos = :binary.match(html, "2026-04-10")
      assert first_row_pos != :nomatch
      assert second_row_pos != :nomatch
      assert elem(first_row_pos, 0) < elem(second_row_pos, 0)
    end

    test "sort_by=latency_ms&sort_dir=desc returns highest latency first", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/monitoring/monitor/#{monitor.id}/logs?sort_by=latency_ms&sort_dir=desc"
        )

      html = render(view)
      pos_900 = :binary.match(html, "900ms")
      pos_50 = :binary.match(html, "50ms")
      assert pos_900 != :nomatch
      assert pos_50 != :nomatch
      assert elem(pos_900, 0) < elem(pos_50, 0)
    end

    test "clicking Time header from default (desc) patches URL to asc", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      view |> element("thead a[href*='sort_by=checked_at']") |> render_click()

      assert_patch(
        view,
        ~p"/monitoring/monitor/#{monitor.id}/logs?page=1&page_size=50&sort_by=checked_at&sort_dir=asc"
      )
    end

    test "clicking active sort column again toggles direction", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/monitoring/monitor/#{monitor.id}/logs?sort_by=checked_at&sort_dir=asc"
        )

      view |> element("thead a[href*='sort_by=checked_at']") |> render_click()

      assert_patch(
        view,
        ~p"/monitoring/monitor/#{monitor.id}/logs?page=1&page_size=50&sort_by=checked_at&sort_dir=desc"
      )
    end

    test "clicking a different column defaults to desc and resets to page=1", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/monitoring/monitor/#{monitor.id}/logs?sort_by=checked_at&sort_dir=asc&page=2&page_size=1"
        )

      view |> element("thead a[href*='sort_by=latency_ms']") |> render_click()

      patched = assert_patch(view)
      assert patched =~ "sort_by=latency_ms"
      assert patched =~ "sort_dir=desc"
      refute patched =~ "page=2"
    end

    test "active sort column shows direction indicator", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(
          conn,
          ~p"/monitoring/monitor/#{monitor.id}/logs?sort_by=latency_ms&sort_dir=asc"
        )

      assert html =~ "h-sort-indicator"
      assert html =~ "↑"
    end

    test "inactive sort columns show no indicator", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(
          conn,
          ~p"/monitoring/monitor/#{monitor.id}/logs?sort_by=latency_ms&sort_dir=asc"
        )

      refute html =~ "↓"
    end

    test "Evidence column header has no sort link", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      html = render(view)
      refute html =~ ~r/h-table-sort-header[^<]*Evidence/
    end

    test "sort params coexist with status filter in URL", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      url =
        ~p"/monitoring/monitor/#{monitor.id}/logs?status=up&sort_by=latency_ms&sort_dir=desc"

      {:ok, _view, html} = live(conn, url)

      assert html =~ "sort_by=latency_ms"
      assert html =~ "status=up"
    end

    test "page links preserve sort params", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      for _ <- 1..6 do
        log_fixture(%{monitor_id: monitor.id})
      end

      url =
        ~p"/monitoring/monitor/#{monitor.id}/logs?sort_by=latency_ms&sort_dir=asc&page_size=3&page=1"

      {:ok, _view, html} = live(conn, url)

      assert html =~ "sort_by=latency_ms"
      assert html =~ "sort_dir=asc"
      assert html =~ "h-pagination-nav"
    end
  end

  describe "technical evidence modal logic" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      {:ok, log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :down,
          status_code: 500,
          latency_ms: 456,
          response_headers: %{"server" => "nginx"},
          response_snippet: "Server Error",
          checked_at: DateTime.utc_now()
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs?page=1")

      %{view: view, log: log}
    end

    test "it opens and closes the technical evidence modal", %{view: view} do
      view |> element("button[phx-click=\"view_evidence\"]") |> render_click()
      assert has_element?(view, "#evidence-modal")
      assert render(view) =~ "nginx"
      assert render(view) =~ "Server Error"

      view |> element("button", "close") |> render_click()
      refute has_element?(view, "#evidence-modal")
    end
  end
end
