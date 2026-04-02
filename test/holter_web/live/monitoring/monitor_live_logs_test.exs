defmodule HolterWeb.Monitoring.MonitorLiveLogsTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Holter.Monitoring

  @monitor_attrs %{
    url: "https://example.local",
    method: :GET,
    interval_seconds: 60,
    logical_state: :active
  }

  setup do
    {:ok, monitor} = Monitoring.create_monitor(@monitor_attrs)
    %{monitor: monitor}
  end

  describe "Logs LiveView" do
    test "renders technical logs page", %{conn: conn, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")
      assert html =~ "Technical Logs"
      assert html =~ monitor.url
    end

    test "displays logs in the table", %{conn: conn, monitor: monitor} do
      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        latency_ms: 123,
        checked_at: DateTime.utc_now()
      })

      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")
      assert html =~ "123ms"
      assert html =~ "SUCCESS"
    end

    test "opens evidence modal when clicking view button", %{conn: conn, monitor: monitor} do
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

      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      view |> element("button.btn-evidence") |> render_click()

      assert has_element?(view, "h2", "Technical Evidence")
      assert render(view) =~ "nginx"
      assert render(view) =~ "Server Error"
    end
  end
end
