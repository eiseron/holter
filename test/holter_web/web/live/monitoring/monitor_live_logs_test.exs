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

  describe "technical logs page" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 123})

      {:ok, view, html} =
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=1")

      %{view: view, html: html}
    end

    test "it displays the monitor URL", %{html: html} do
      assert html =~ "https://example.local"
    end

    test "when logs exist in the system it displays the latency value", %{html: html} do
      assert html =~ "123ms"
    end

    test "when logs exist in the system it displays the capitalized status", %{html: html} do
      assert html =~ "UP"
    end
  end

  describe "when filtering and paginating logs" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      for i <- 1..6 do
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          checked_at: DateTime.add(DateTime.utc_now(), i, :second)
        })
      end

      log_fixture(%{monitor_id: monitor.id, status: :down})

      %{conn: conn, monitor: monitor, workspace: workspace}
    end

    test "loads with filters from query params", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(
          conn,
          ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?status=down&page=1&page_size=5"
        )

      assert html =~ "DOWN"
      refute html =~ "UP"
    end

    test "updates query params on filter change", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=1&page_size=5"
        )

      view
      |> form("form[phx-change=\"filter_updated\"]")
      |> render_change(%{filters: %{status: "down", page_size: "5"}})

      assert_patch(
        view,
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page_size=5&status=down"
      )
    end

    test "loads second page via query param", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=2&page_size=5"
        )

      assert render(view) =~ "Página 2 de 2"
    end

    test "clicking next page updates url", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(
          conn,
          ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page=1&page_size=5"
        )

      view |> element("a", "2") |> render_click()

      assert_patch(
        view,
        ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs?page_size=5&page=2"
      )
    end
  end

  describe "when clicking view evidence" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      {:ok, _log} =
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

      view |> element("button[phx-click=\"view_evidence\"]") |> render_click()
      %{view: view}
    end

    test "it opens the technical evidence modal", %{view: view} do
      assert has_element?(view, "h2", "Evidência Técnica")
    end

    test "it displays recorded headers in the modal", %{view: view} do
      assert render(view) =~ "nginx"
    end

    test "it displays the response snippet in the modal", %{view: view} do
      assert render(view) =~ "Server Error"
    end
  end
end
