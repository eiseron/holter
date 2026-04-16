defmodule HolterWeb.Api.MonitorLogControllerTest do
  use HolterWeb.ConnCase

  setup %{conn: conn} do
    workspace = workspace_fixture()
    monitor = monitor_fixture(%{workspace_id: workspace.id})
    {:ok, conn: put_req_header(conn, "accept", "application/json"), monitor: monitor}
  end

  describe "GET /api/v1/monitors/:monitor_id/logs" do
    test "Lists logs for the monitor", %{conn: conn, monitor: monitor} do
      monitor_log_fixture(%{monitor_id: monitor.id})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/logs")

      assert %{"data" => [_]} = json_response(conn, 200)
    end

    test "Filters logs by status", %{conn: conn, monitor: monitor} do
      monitor_log_fixture(%{monitor_id: monitor.id, status: :up})
      monitor_log_fixture(%{monitor_id: monitor.id, status: :down})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/logs?status=up")

      assert %{"data" => [log]} = json_response(conn, 200)
      assert log["status"] == "up"
    end

    test "Sorts logs by latency_ms", %{conn: conn, monitor: monitor} do
      monitor_log_fixture(%{monitor_id: monitor.id, latency_ms: 100})
      monitor_log_fixture(%{monitor_id: monitor.id, latency_ms: 200})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/logs?sort_by=latency_ms&sort_dir=desc")

      assert %{"data" => [l1, l2]} = json_response(conn, 200)
      assert l1["latency_ms"] == 200
      assert l2["latency_ms"] == 100
    end
  end

  describe "GET /api/v1/monitors/:monitor_id/logs/:id" do
    test "Returns log details with evidence", %{conn: conn, monitor: monitor} do
      log = monitor_log_fixture(%{monitor_id: monitor.id, response_snippet: "<html>"})
      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/logs/#{log.id}")
      assert json_response(conn, 200)["data"]["response_snippet"] == "<html>"
    end

    test "Returns 404 if log belongs to another monitor", %{conn: conn, monitor: monitor} do
      other_monitor = monitor_fixture()
      log = monitor_log_fixture(%{monitor_id: other_monitor.id})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/logs/#{log.id}")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/monitors/:monitor_id/logs/:id redirect_list" do
    setup %{conn: conn, monitor: monitor} do
      log =
        monitor_log_fixture(%{
          monitor_id: monitor.id,
          redirect_count: 1,
          redirect_list: [
            %{"url" => "https://example.com", "ip" => "1.2.3.4", "status_code" => 301},
            %{"url" => "https://www.example.com", "ip" => "1.2.3.5", "status_code" => 200}
          ]
        })

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/logs/#{log.id}")
      redirect_list = json_response(conn, 200)["data"]["redirect_list"]
      [hop1, hop2] = redirect_list
      %{redirect_list: redirect_list, hop1: hop1, hop2: hop2}
    end

    test "list has two entries", %{redirect_list: redirect_list} do
      assert length(redirect_list) == 2
    end

    test "hop 1 url is correct", %{hop1: hop1} do
      assert hop1["url"] == "https://example.com"
    end

    test "hop 1 ip is correct", %{hop1: hop1} do
      assert hop1["ip"] == "1.2.3.4"
    end

    test "hop 1 status_code is 301", %{hop1: hop1} do
      assert hop1["status_code"] == 301
    end

    test "hop 2 status_code is 200", %{hop2: hop2} do
      assert hop2["status_code"] == 200
    end
  end
end
