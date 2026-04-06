defmodule HolterWeb.Web.Monitoring.MonitorLiveLogsInheritanceTest do
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

  describe "evidence inheritance" do
    test "inherits from last valid log even with multiple empty logs in between", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, log_with_ev} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :success,
          response_headers: %{"server" => "nginx/deep-heritage"},
          response_snippet: "Real Payload",
          checked_at: DateTime.add(now, -180, :second)
        })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        response_headers: %{},
        checked_at: DateTime.add(now, -120, :second)
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        response_snippet: "",
        checked_at: DateTime.add(now, -60, :second)
      })

      {:ok, newest_log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :success,
          checked_at: now
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs")

      view
      |> render_click("view_evidence", %{"id" => newest_log.id})

      html = render(view)

      assert html =~ "nginx/deep-heritage"
      assert html =~ "Real Payload"
      assert html =~ "This check did not capture new evidence"

      source_time = Calendar.strftime(log_with_ev.checked_at, "%Y-%m-%d %H:%M:%S")
      assert html =~ source_time
    end

    test "FAILURE with error correctly inherits technical context from previous SUCCESS", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        response_headers: %{"via" => "success-context"},
        response_snippet: "Valid Success Data",
        checked_at: DateTime.add(now, -60, :second)
      })

      {:ok, failure_log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :failure,
          error_message: "Connection Timeout",
          checked_at: now
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs")

      view
      |> render_click("view_evidence", %{"id" => failure_log.id})

      html = render(view)

      assert html =~ "Connection Timeout"

      assert html =~ "success-context"
      assert html =~ "Valid Success Data"
      assert html =~ "This check did not capture new evidence"
    end

    test "inherits across multiple sequential FAILURES back to the last valid capture", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        response_headers: %{"x-trace" => "original-capture"},
        checked_at: DateTime.add(now, -180, :second)
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :failure,
        error_message: "First Failure (Timeout)",
        checked_at: DateTime.add(now, -120, :second)
      })

      {:ok, clicked_failure} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :failure,
          error_message: "Current Failure (Connection Refused)",
          checked_at: now
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/#{monitor.id}/logs")

      view
      |> render_click("view_evidence", %{"id" => clicked_failure.id})

      html = render(view)

      assert html =~ "Current Failure (Connection Refused)"
      assert html =~ "original-capture"
      assert html =~ "This check did not capture new evidence"
    end
  end
end
