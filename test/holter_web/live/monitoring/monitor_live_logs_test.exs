defmodule HolterWeb.Monitoring.MonitorLiveLogsTest do
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

  describe "when rendering technical logs page" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      {:ok, view, html} =
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs")

      %{view: view, html: html}
    end

    test "it displays the page title", %{html: html} do
      assert html =~ "Logs Técnicos"
    end

    test "it displays the monitor URL", %{monitor: monitor, html: html} do
      assert html =~ monitor.url
    end
  end

  describe "when logs exist in the system" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        latency_ms: 123,
        checked_at: DateTime.utc_now()
      })

      {:ok, view, html} =
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs")

      %{view: view, html: html}
    end

    test "it displays the latency value", %{html: html} do
      assert html =~ "123ms"
    end

    test "it displays the capitalized status", %{html: html} do
      assert html =~ "SUCCESS"
    end
  end

  describe "when clicking view evidence" do
    setup %{conn: conn, monitor: monitor, workspace: workspace} do
      {:ok, _log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :failure,
          status_code: 500,
          latency_ms: 456,
          response_headers: %{"server" => "nginx"},
          response_snippet: "Server Error",
          checked_at: DateTime.utc_now()
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs")

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
