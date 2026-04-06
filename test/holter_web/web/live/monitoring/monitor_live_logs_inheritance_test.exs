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
    test "inherits from previous log when current log has no evidence", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :failure,
        response_headers: %{"server" => "nginx/inherited"},
        response_snippet: "Old Content",
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
      assert html =~ "nginx/inherited"
      assert html =~ "Old Content"
      assert html =~ "This check did not capture new evidence"
    end

    test "skips logs with empty headers map and inherits from last valid log", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :failure,
        response_headers: %{"x-test" => "valid-target"},
        response_snippet: "Valid Content",
        checked_at: DateTime.add(now, -120, :second)
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :success,
        response_headers: %{},
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
      assert html =~ "valid-target"
      assert html =~ "Valid Content"
      assert html =~ "This check did not capture new evidence"
    end

    test "skips logs with empty response snippet and inherits from last valid log", %{
      conn: conn,
      monitor: monitor,
      workspace: workspace
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :failure,
        response_snippet: "Target Content",
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
      assert html =~ "Target Content"
      assert html =~ "This check did not capture new evidence"
    end
  end
end
