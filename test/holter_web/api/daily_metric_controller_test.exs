defmodule HolterWeb.Api.DailyMetricControllerTest do
  use HolterWeb.ConnCase

  setup %{conn: conn} do
    monitor = monitor_fixture()
    {:ok, conn: put_req_header(conn, "accept", "application/json"), monitor: monitor}
  end

  describe "GET /api/v1/monitors/:monitor_id/daily_metrics" do
    test "Lists daily metrics for the monitor", %{conn: conn, monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/daily_metrics")

      assert %{"data" => [_]} = json_response(conn, 200)
    end
  end
end
