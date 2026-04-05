defmodule HolterWeb.MonitorControllerTest do
  use HolterWeb.ConnCase

  alias Holter.Monitoring

  setup %{conn: conn} do
    workspace = workspace_fixture(%{name: "Test Workspace", slug: "test-workspace"})
    {:ok, conn: put_req_header(conn, "accept", "application/json"), workspace: workspace}
  end

  describe "GET /api/v1/workspaces/:workspace_slug/monitors" do
    test "Lists monitors for the workspace", %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id})

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors")

      assert %{"data" => [_]} = json_response(conn, 200)
    end

    test "Filters monitors by health_status", %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id, health_status: :down})
      monitor_fixture(%{workspace_id: workspace.id, health_status: :up})

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors?health_status=down")

      assert %{"data" => [m]} = json_response(conn, 200)
      assert m["health_status"] == "down"
    end

    test "Returns empty list if workspace has no monitors", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_slug/monitors" do
    @valid_attrs %{
      url: "https://api-test.local",
      method: "get",
      interval_seconds: 60
    }

    test "Creates a monitor and returns 201", %{conn: conn, workspace: workspace} do
      conn = post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors", monitor: @valid_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert Monitoring.get_monitor!(id).workspace_id == workspace.id
    end

    test "Returns 422 for invalid data", %{conn: conn, workspace: workspace} do
      conn = post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors", monitor: %{url: nil})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "GET /api/v1/workspaces/:workspace_slug/monitors/:id" do
    test "Returns monitor details", %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors/#{monitor.id}")
      assert json_response(conn, 200)["data"]["id"] == monitor.id
    end

    test "Returns 404 if monitor belongs to another workspace", %{conn: conn, workspace: workspace} do
      other_workspace = workspace_fixture()
      monitor = monitor_fixture(%{workspace_id: other_workspace.id})

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors/#{monitor.id}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/workspaces/:workspace_slug/monitors/:id" do
    test "Updates monitor and returns 200", %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      conn =
        put(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors/#{monitor.id}",
          monitor: %{url: "https://updated.local"}
        )

      assert json_response(conn, 200)["data"]["url"] == "https://updated.local"
    end
  end

  describe "DELETE /api/v1/workspaces/:workspace_slug/monitors/:id" do
    test "Deletes monitor and returns 204", %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      conn = delete(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors/#{monitor.id}")
      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Monitoring.get_monitor!(monitor.id) end
    end
  end
end
