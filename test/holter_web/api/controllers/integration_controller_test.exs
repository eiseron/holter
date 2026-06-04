defmodule HolterWeb.Api.IntegrationControllerTest do
  use HolterWeb.ConnCase, async: false

  import Mox
  import OpenApiSpex.TestAssertions

  alias Holter.Integrations
  alias HolterWeb.Api.ApiSpec

  setup :verify_on_exit!

  setup %{conn: conn, current_user: user} do
    workspace = workspace_fixture(%{owner: user, name: "API WS", slug: "api-ws"})
    api_spec = ApiSpec.spec()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> authed_api_conn({user, workspace})

    {:ok, conn: conn, workspace: workspace, api_spec: api_spec, current_user: user}
  end

  defp json_patch(conn, path, body), do: patch(conn, path, Jason.encode!(body))

  describe "GET /api/v1/workspaces/:workspace_slug/integrations" do
    test "lists integrations for the workspace", %{
      conn: conn,
      workspace: ws,
      api_spec: spec
    } do
      integration_fixture(workspace_id: ws.id, provider: :google_ads, name: "Ads One")

      conn = get(conn, ~p"/api/v1/workspaces/#{ws.slug}/integrations")
      body = json_response(conn, 200)

      assert %{"data" => [item]} = body
      assert item["name"] == "Ads One"
      assert item["provider"] == "google_ads"
      assert_schema(body, "IntegrationList", spec)
    end

    test "returns 401 without a bearer token", %{workspace: ws} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/v1/workspaces/#{ws.slug}/integrations")

      assert json_response(conn, 401)
    end

    test "returns 403 without read:integrations scope", %{
      conn: _conn,
      workspace: ws,
      current_user: user
    } do
      narrow_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> authed_api_conn({user, ws}, scopes: ["read:monitors"])

      conn = get(narrow_conn, ~p"/api/v1/workspaces/#{ws.slug}/integrations")
      body = json_response(conn, 403)

      assert body["error"] == "forbidden"
      assert body["required_scope"] == "read:integrations"
    end

    test "returns 404 for unknown workspace slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/does-not-exist/integrations")
      assert json_response(conn, 404)
    end

    test "returns 403 when slug belongs to another workspace", %{
      conn: _conn,
      current_user: user
    } do
      ws_a = workspace_fixture(%{owner: user, slug: "ws-a"})
      %{user: stranger} = verified_user_fixture()
      ws_b = workspace_fixture(%{owner: stranger, slug: "ws-b"})

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> authed_api_conn({user, ws_a})
        |> get(~p"/api/v1/workspaces/#{ws_b.slug}/integrations")

      assert json_response(conn, 403)
    end
  end

  describe "GET /api/v1/integrations/:id" do
    test "returns the integration", %{conn: conn, workspace: ws, api_spec: spec} do
      integration = integration_fixture(workspace_id: ws.id)

      conn = get(conn, ~p"/api/v1/integrations/#{integration.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == integration.id
      assert_schema(body, "IntegrationResponse", spec)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/integrations/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end

    test "returns 403 when integration belongs to another workspace", %{
      conn: conn,
      current_user: user
    } do
      %{user: stranger} = verified_user_fixture()
      other_ws = workspace_fixture(%{owner: stranger})
      foreign = integration_fixture(workspace_id: other_ws.id)

      _ = user
      conn = get(conn, ~p"/api/v1/integrations/#{foreign.id}")
      assert json_response(conn, 403)
    end
  end

  describe "PATCH /api/v1/integrations/:id" do
    test "updates name and settings", %{conn: conn, workspace: ws, api_spec: spec} do
      integration = integration_fixture(workspace_id: ws.id)

      conn =
        json_patch(conn, ~p"/api/v1/integrations/#{integration.id}", %{
          name: "Renamed",
          settings: %{"customer_id" => "9999"}
        })

      body = json_response(conn, 200)

      assert body["data"]["name"] == "Renamed"
      assert body["data"]["settings"]["customer_id"] == "9999"
      assert_schema(body, "IntegrationResponse", spec)
    end

    test "returns 422 with validation errors for empty name", %{conn: conn, workspace: ws} do
      integration = integration_fixture(workspace_id: ws.id)

      conn = json_patch(conn, ~p"/api/v1/integrations/#{integration.id}", %{name: ""})

      body = json_response(conn, 422)
      assert body["error"]["code"] == "validation_failed"
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn =
        json_patch(conn, ~p"/api/v1/integrations/00000000-0000-0000-0000-000000000000", %{
          name: "X"
        })

      assert json_response(conn, 404)
    end

    test "returns 403 without write:integrations scope", %{
      conn: _conn,
      workspace: ws,
      current_user: user
    } do
      integration = integration_fixture(workspace_id: ws.id)

      narrow =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> authed_api_conn({user, ws}, scopes: ["read:integrations"])

      conn = json_patch(narrow, ~p"/api/v1/integrations/#{integration.id}", %{name: "X"})
      body = json_response(conn, 403)

      assert body["required_scope"] == "write:integrations"
    end
  end

  describe "DELETE /api/v1/integrations/:id" do
    test "disconnects and returns 204 even without a provider impl", %{
      conn: conn,
      workspace: ws
    } do
      integration = integration_fixture(workspace_id: ws.id)

      conn = delete(conn, ~p"/api/v1/integrations/#{integration.id}")

      assert conn.status == 204
      assert {:error, :not_found} = Integrations.get_integration(integration.id)
    end

    test "calls provider revoke when an implementation is registered", %{
      conn: conn,
      workspace: ws
    } do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      integration = integration_fixture(workspace_id: ws.id, provider: :slack)

      expect(Holter.Integrations.ProviderMock, :revoke, fn _creds -> :ok end)

      conn = delete(conn, ~p"/api/v1/integrations/#{integration.id}")

      assert conn.status == 204
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/integrations/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end
end
