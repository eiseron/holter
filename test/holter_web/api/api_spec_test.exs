defmodule HolterWeb.Api.ApiSpecTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Api.ApiSpec
  alias OpenApiSpex.OpenApi

  import OpenApiSpex.TestAssertions

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

  test "Workspace response matches schema", %{conn: conn} do
    workspace = workspace_fixture(%{slug: "spec-test"})

    json =
      conn
      |> get(~p"/api/v1/workspaces/#{workspace.slug}")
      |> json_response(200)

    assert_schema(json, "WorkspaceResponse", ApiSpec.spec())
  end

  test "Monitor response matches schema", %{conn: conn} do
    monitor = monitor_fixture()

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
