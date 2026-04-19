defmodule HolterWeb.Api.IncidentControllerTest do
  use HolterWeb.ConnCase

  import OpenApiSpex.TestAssertions
  alias HolterWeb.Api.MonitoringApiSpec

  setup %{conn: conn} do
    monitor = monitor_fixture()
    api_spec = MonitoringApiSpec.spec()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn, monitor: monitor, api_spec: api_spec}
  end

  describe "GET /api/v1/incidents/:id - Schema Sync Verification" do
    test "response matches the Incident schema defined in the controller operation (FAILING BUG)",
         %{
           conn: conn,
           monitor: monitor,
           api_spec: spec
         } do
      incident = incident_fixture(%{monitor_id: monitor.id})

      conn = get(conn, ~p"/api/v1/incidents/#{incident.id}")
      body = json_response(conn, 200)

      assert_schema(body, "Incident", spec)
    end
  end

  describe "GET /api/v1/monitors/:monitor_id/incidents" do
    test "Lists incidents for the monitor and matches schema", %{
      conn: conn,
      monitor: monitor,
      api_spec: spec
    } do
      incident_fixture(%{monitor_id: monitor.id})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/incidents")
      body = json_response(conn, 200)

      assert %{"data" => [_]} = body
      assert_schema(body, "IncidentList", spec)
    end

    test "returns empty list when monitor has no incidents", %{
      conn: conn,
      monitor: monitor,
      api_spec: spec
    } do
      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/incidents")
      body = json_response(conn, 200)

      assert %{"data" => []} = body
      assert_schema(body, "IncidentList", spec)
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

    test "returns 404 for an unknown incident UUID", %{conn: conn, api_spec: spec} do
      conn = get(conn, ~p"/api/v1/incidents/#{Ecto.UUID.generate()}")
      body = json_response(conn, 404)

      assert %{"error" => _} = body
      assert_schema(body, "Error", spec)
    end
  end
end
