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

  describe "GET /api/v1/incidents/:id" do
    test "returns 200 with the incident type for an existing incident",
         %{conn: conn, monitor: monitor} do
      incident = incident_fixture(%{monitor_id: monitor.id, type: :downtime})

      conn = get(conn, ~p"/api/v1/incidents/#{incident.id}")

      assert %{"data" => %{"type" => "downtime"}} = json_response(conn, 200)
    end

    test "returns the incident started_at timestamp in the response",
         %{conn: conn, monitor: monitor} do
      incident = incident_fixture(%{monitor_id: monitor.id})

      conn = get(conn, ~p"/api/v1/incidents/#{incident.id}")

      assert %{"data" => %{"started_at" => _}} = json_response(conn, 200)
    end

    test "returns the incident root_cause in the response when set",
         %{conn: conn, monitor: monitor} do
      incident =
        incident_fixture(%{
          monitor_id: monitor.id,
          root_cause: "Certificate expired"
        })

      conn = get(conn, ~p"/api/v1/incidents/#{incident.id}")

      assert %{"data" => %{"root_cause" => "Certificate expired"}} = json_response(conn, 200)
    end

    test "returns 404 for an unknown incident UUID", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/incidents/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end
end
