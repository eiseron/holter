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
    %{monitor: monitor}
  end

  describe "evidence inheritance" do
    test "inherits from last valid log even with multiple empty logs in between", %{
      conn: conn,
      monitor: monitor
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, log_with_ev} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          response_headers: %{"server" => "nginx/deep-heritage"},
          response_snippet: "Real Payload",
          checked_at: DateTime.add(now, -180, :second)
        })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        response_headers: %{},
        checked_at: DateTime.add(now, -120, :second)
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        response_snippet: "",
        checked_at: DateTime.add(now, -60, :second)
      })

      {:ok, newest_log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          checked_at: now
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/logs/#{newest_log.id}")

      html = render(view)

      assert html =~ "nginx/deep-heritage"
      assert html =~ "Real Payload"
      assert html =~ "h-evidence-inherited-notice"

      source_time = Calendar.strftime(log_with_ev.checked_at, "%Y-%m-%d %H:%M:%S")
      assert html =~ source_time
    end

    test "FAILURE with error correctly inherits technical context from previous SUCCESS", %{
      conn: conn,
      monitor: monitor
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        response_headers: %{"via" => "success-context"},
        response_snippet: "Valid Success Data",
        checked_at: DateTime.add(now, -60, :second)
      })

      {:ok, failure_log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :down,
          error_message: "Connection Timeout",
          checked_at: now
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/logs/#{failure_log.id}")

      html = render(view)

      assert html =~ "Connection Timeout"
      assert html =~ "success-context"
      assert html =~ "Valid Success Data"
      assert html =~ "h-evidence-inherited-notice"
      assert html =~ "last known good state"
      refute html =~ "response was unchanged since the last collection"
    end

    test "shows 'last known good state' label when DOWN log inherits from UP log", %{
      conn: conn,
      monitor: monitor
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        status_code: 200,
        response_headers: %{"content-type" => "text/html"},
        checked_at: DateTime.add(now, -60, :second)
      })

      {:ok, failure_log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :down,
          error_message: "socket closed",
          checked_at: now
        })

      {:ok, view, _html} = live(conn, ~p"/monitoring/logs/#{failure_log.id}")
      html = render(view)

      assert html =~ "last known good state"
      assert html =~ "h-evidence-inherited-notice"
      refute html =~ "response was unchanged since the last collection"
    end

    test "shows 'response unchanged' label when UP log inherits from UP log", %{
      conn: conn,
      monitor: monitor
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        response_headers: %{"x-cache" => "HIT"},
        checked_at: DateTime.add(now, -60, :second)
      })

      {:ok, up_log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          checked_at: now
        })

      {:ok, view, _html} = live(conn, ~p"/monitoring/logs/#{up_log.id}")
      html = render(view)

      assert html =~ "response was unchanged since the last collection"
      assert html =~ "h-evidence-inherited-notice"
      refute html =~ "last known good state"
    end

    test "inherits across multiple sequential FAILURES back to the last valid capture", %{
      conn: conn,
      monitor: monitor
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        response_headers: %{"x-trace" => "original-capture"},
        checked_at: DateTime.add(now, -180, :second)
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :down,
        error_message: "First Failure (Timeout)",
        checked_at: DateTime.add(now, -120, :second)
      })

      {:ok, clicked_failure} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :down,
          error_message: "Current Failure (Connection Refused)",
          checked_at: now
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/logs/#{clicked_failure.id}")

      html = render(view)

      assert html =~ "Current Failure (Connection Refused)"
      assert html =~ "original-capture"
      assert html =~ "h-evidence-inherited-notice"
    end
  end
end
