defmodule HolterWeb.Api.IncidentControllerTest do
  use HolterWeb.ConnCase

  setup %{conn: conn} do
    monitor = monitor_fixture()
    {:ok, conn: put_req_header(conn, "accept", "application/json"), monitor: monitor}
  end

  describe "GET /api/v1/monitors/:monitor_id/incidents" do
    test "Lists incidents for the monitor", %{conn: conn, monitor: monitor} do
      incident_fixture(%{monitor_id: monitor.id})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/incidents")

      assert %{"data" => [_]} = json_response(conn, 200)
    end
  end
end
