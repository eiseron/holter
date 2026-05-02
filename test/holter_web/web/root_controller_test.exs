defmodule HolterWeb.Web.RootControllerTest do
  use HolterWeb.ConnCase, async: true

  describe "GET /" do
    @tag :guest
    test "redirects an unauthenticated visitor to /identity/login", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert redirected_to(conn) == "/identity/login"
    end

    test "redirects a signed-in user to the first workspace dashboard", %{
      conn: conn,
      current_workspace: workspace
    } do
      conn = get(conn, ~p"/")

      assert redirected_to(conn) == "/monitoring/workspaces/#{workspace.slug}/monitors"
    end
  end
end
