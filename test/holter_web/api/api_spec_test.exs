defmodule HolterWeb.Api.ApiSpecTest do
  use HolterWeb.ConnCase, async: true

  import OpenApiSpex.TestAssertions

  alias HolterWeb.Api.ApiSpec
  alias OpenApiSpex.OpenApi

  setup %{conn: conn, current_user: user} do
    workspace = workspace_fixture()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> authed_api_conn({user, workspace})

    {:ok, conn: conn, workspace: workspace, current_user: user}
  end

  test "API spec is valid" do
    spec = ApiSpec.spec()
    assert %OpenApi{info: %{title: "Holter API"}} = spec
  end

  test "API spec has correct server URL" do
    spec = ApiSpec.spec()
    assert [%OpenApiSpex.Server{url: "/"}] = spec.servers
  end

  test "generated paths have correct API v1 prefix", %{conn: conn} do
    conn = get(conn, "/api/openapi")
    assert json_response(conn, 200)
  end

  test "generated paths use OpenAPI format and v1 prefix", %{conn: conn} do
    conn = get(conn, "/api/openapi")
    json = json_response(conn, 200)
    paths = json["paths"]
    assert Map.has_key?(paths, "/api/v1/workspaces/{workspace_slug}")
  end

  test "generated paths do not have duplicate API prefix", %{conn: conn} do
    conn = get(conn, "/api/openapi")
    json = json_response(conn, 200)
    paths = json["paths"]
    refute Enum.any?(Map.keys(paths), fn path -> String.starts_with?(path, "/api/api/v1") end)
  end

  test "Workspace response matches schema", %{conn: conn, workspace: workspace} do
    json =
      conn
      |> get(~p"/api/v1/workspaces/#{workspace.slug}")
      |> json_response(200)

    assert_schema(json, "WorkspaceResponse", ApiSpec.spec())
  end

  test "Monitor response matches schema", %{conn: conn, workspace: workspace} do
    monitor = monitor_fixture(%{workspace_id: workspace.id})

    json =
      conn
      |> get(~p"/api/v1/monitors/#{monitor.id}")
      |> json_response(200)

    assert_schema(json, "MonitorResponse", ApiSpec.spec())
  end

  test "Swagger UI is accessible" do
    conn = get(build_conn(), "/api/swagger")
    assert html_response(conn, 200) =~ "swagger-ui"
  end

  test "Swagger UI points to correct spec" do
    conn = get(build_conn(), "/api/swagger")
    assert html_response(conn, 200) =~ "/api/openapi"
  end
end
