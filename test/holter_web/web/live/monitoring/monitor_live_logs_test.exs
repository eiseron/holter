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
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=1")

      %{view: view, html: html}
    end

    test "it displays the monitor URL and technical context", %{html: html} do
      assert html =~ "https://example.local"
      assert html =~ "UP"
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
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?status=down&start_date=2026-04-08&page=1"

      {:ok, _view, html} = live(conn, url)

      assert html =~ "DOWN"
      assert html =~ "2026-04-08"

      refute html =~ "UP"
      refute html =~ "2026-04-07"
    end

    test "renders empty state when no logs match filters", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      url =
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?status=compromised&page=1"

      {:ok, _view, html} = live(conn, url)

      assert html =~ "Página 1 de 1"
      refute html =~ "h-status-pill"
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
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?status=up&page_size=5&page=1"

      {:ok, view, _html} = live(conn, url)

      view |> element("a", "2") |> render_click()

      assert_patch(
        view,
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?status=up&page_size=5&page=2"
      )
    end

    test "handles out of bounds page numbers by resetting to last valid page", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      url =
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=10&page_size=5"

      {:ok, view, _html} = live(conn, url)

      assert render(view) =~ "Página 3 de 3"
    end

    test "updating filter resets to page 1", %{conn: conn, monitor: monitor, workspace: workspace} do
      url =
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=2&page_size=5"

      {:ok, view, _html} = live(conn, url)

      view
      |> form("form[phx-change=\"filter_updated\"]")
      |> render_change(%{filters: %{status: "down", page_size: "5"}})

      assert_patch(
        view,
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page_size=5&status=down"
      )
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
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=1")

      %{view: view, log: log}
    end

    test "it opens and closes the technical evidence modal", %{view: view} do
      view |> element("button[phx-click=\"view_evidence\"]") |> render_click()
      assert has_element?(view, "h2", "Evidência Técnica")
      assert render(view) =~ "nginx"
      assert render(view) =~ "Server Error"

      view |> element("button", "Fechar") |> render_click()
      refute has_element?(view, "h2", "Evidência Técnica")
    end
  end
end
