defmodule HolterWeb.Plugs.AssignIntegrationWorkspaceTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Plugs.AssignIntegrationWorkspace

  describe "call/2" do
    test "assigns the workspace resolved from the OAuth state claims", %{
      conn: conn,
      current_workspace: ws
    } do
      conn =
        conn
        |> Plug.Conn.assign(:oauth_state_claims, %{workspace_id: ws.id})
        |> AssignIntegrationWorkspace.call([])

      assert conn.assigns.current_workspace.id == ws.id
    end

    test "assigns the workspace resolved from the path slug", %{conn: conn, current_workspace: ws} do
      conn =
        conn
        |> Map.put(:path_params, %{"workspace_slug" => ws.slug})
        |> AssignIntegrationWorkspace.call([])

      assert conn.assigns.current_workspace.id == ws.id
    end

    test "leaves the conn untouched when no workspace can be resolved", %{conn: conn} do
      conn = AssignIntegrationWorkspace.call(conn, [])

      refute Map.has_key?(conn.assigns, :current_workspace)
    end

    test "leaves the conn untouched when the slug matches no workspace", %{conn: conn} do
      conn =
        conn
        |> Map.put(:path_params, %{"workspace_slug" => "no-such-workspace"})
        |> AssignIntegrationWorkspace.call([])

      refute Map.has_key?(conn.assigns, :current_workspace)
    end
  end
end
