defmodule HolterWeb.MonitorControllerTest do
  use HolterWeb.ConnCase

  alias Holter.Monitoring

  setup %{conn: conn} do
    org = organization_fixture(%{name: "Test Org", slug: "test-org"})
    {:ok, conn: put_req_header(conn, "accept", "application/json"), org: org}
  end

  describe "GET /api/orgs/:org_slug/monitoring/monitors" do
    test "Lists monitors for the organization", %{conn: conn, org: org} do
      monitor_fixture(%{organization_id: org.id})

      conn = get(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors")

      assert %{"data" => [_]} = json_response(conn, 200)
    end

    test "Filters monitors by health_status", %{conn: conn, org: org} do
      monitor_fixture(%{organization_id: org.id, health_status: :down})
      monitor_fixture(%{organization_id: org.id, health_status: :up})

      conn = get(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors?health_status=down")

      assert %{"data" => [m]} = json_response(conn, 200)
      assert m["health_status"] == "down"
    end

    test "Returns empty list if organization has no monitors", %{conn: conn, org: org} do
      conn = get(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/orgs/:org_slug/monitoring/monitors" do
    @valid_attrs %{
      url: "https://api-test.local",
      method: "get",
      interval_seconds: 60
    }

    test "Creates a monitor and returns 201", %{conn: conn, org: org} do
      conn = post(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors", monitor: @valid_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert Monitoring.get_monitor!(id).organization_id == org.id
    end

    test "Returns 422 for invalid data", %{conn: conn, org: org} do
      conn = post(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors", monitor: %{url: nil})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "GET /api/orgs/:org_slug/monitoring/monitors/:id" do
    test "Returns monitor details", %{conn: conn, org: org} do
      monitor = monitor_fixture(%{organization_id: org.id})
      conn = get(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors/#{monitor.id}")
      assert json_response(conn, 200)["data"]["id"] == monitor.id
    end

    test "Returns 404 if monitor belongs to another organization", %{conn: conn, org: org} do
      other_org = organization_fixture()
      monitor = monitor_fixture(%{organization_id: other_org.id})

      conn = get(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors/#{monitor.id}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/orgs/:org_slug/monitoring/monitors/:id" do
    test "Updates monitor and returns 200", %{conn: conn, org: org} do
      monitor = monitor_fixture(%{organization_id: org.id})

      conn =
        put(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors/#{monitor.id}",
          monitor: %{url: "https://updated.local"}
        )

      assert json_response(conn, 200)["data"]["url"] == "https://updated.local"
    end
  end

  describe "DELETE /api/orgs/:org_slug/monitoring/monitors/:id" do
    test "Deletes monitor and returns 204", %{conn: conn, org: org} do
      monitor = monitor_fixture(%{organization_id: org.id})

      conn = delete(conn, ~p"/api/orgs/#{org.slug}/monitoring/monitors/#{monitor.id}")
      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Monitoring.get_monitor!(monitor.id) end
    end
  end
end
