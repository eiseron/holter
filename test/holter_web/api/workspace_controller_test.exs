defmodule HolterWeb.Api.WorkspaceControllerTest do
  use HolterWeb.ConnCase

  setup %{conn: conn} do
    workspace = workspace_fixture(%{slug: "test-workspace"})
    {:ok, conn: put_req_header(conn, "accept", "application/json"), workspace: workspace}
  end

  describe "GET /api/v1/workspaces/:workspace_slug" do
    test "Returns workspace details", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}")
      assert json_response(conn, 200)["data"]["slug"] == workspace.slug
    end

    test "Returns 404 for non-existent workspace", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/invalid")
      assert json_response(conn, 404)
    end
  end
end
