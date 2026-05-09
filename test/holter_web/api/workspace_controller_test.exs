defmodule HolterWeb.Api.WorkspaceControllerTest do
  use HolterWeb.ConnCase

  setup %{conn: conn, current_user: user} do
    workspace = workspace_fixture(%{slug: "test-workspace"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> authed_api_conn({user, workspace})

    {:ok, conn: conn, workspace: workspace, current_user: user}
  end

  describe "GET /api/v1/workspaces/:workspace_slug" do
    test "Returns workspace details", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}")
      assert json_response(conn, 200)["data"]["slug"] == workspace.slug
    end

    test "Returns 403 for a different workspace's slug", %{conn: conn} do
      other = workspace_fixture(%{slug: "other-workspace"})
      conn = get(conn, ~p"/api/v1/workspaces/#{other.slug}")
      assert json_response(conn, 403)
    end

    test "Returns 404 for non-existent workspace", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/invalid")
      assert json_response(conn, 404)
    end
  end
end
