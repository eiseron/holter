defmodule HolterWeb.ObservabilityHookTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "on_mount/4 integration via LiveView" do
    setup do
      %{monitor: monitor_fixture()}
    end

    test "hook runs without error during mount", %{conn: conn, monitor: monitor} do
      {:ok, _view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
    end

    test "hook sets session_id in Logger metadata from session", %{conn: conn, monitor: monitor} do
      conn = init_test_session(conn, %{"session_id" => "test-session-123"})
      {:ok, _view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert Logger.metadata()[:session_id] == "test-session-123"
    end

    test "hook sets context to :live_view in Logger metadata", %{conn: conn, monitor: monitor} do
      {:ok, _view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert Logger.metadata()[:context] == :live_view
    end

    test "LiveView mounts successfully without session (Etc/UTC timezone fallback)", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert is_binary(html)
    end
  end
end
