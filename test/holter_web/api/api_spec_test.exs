defmodule HolterWeb.Api.ApiSpecTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Api.ApiSpec
  alias OpenApiSpex.OpenApi

  import OpenApiSpex.TestAssertions

  test "API spec is valid and has correct server URL" do
    spec = ApiSpec.spec()
    assert %OpenApi{info: %{title: "Holter API"}} = spec

    # Garante que o server URL é a raiz para evitar duplicação com os escopos do router
    assert [%OpenApiSpex.Server{url: "/"}] = spec.servers
  end

  test "generated paths have correct API v1 prefix", %{conn: conn} do
    # Verifica o endpoint que renderiza o spec JSON
    conn = get(conn, "/api/openapi")
    assert json = json_response(conn, 200)

    # Verifica se os caminhos no JSON usam o formato OpenAPI {param} e começam com /api/v1/
    paths = json["paths"]
    assert Map.has_key?(paths, "/api/v1/workspaces/{workspace_slug}")
    
    # Verifica se NÃO existe nenhum caminho com prefixo duplicado /api/api/v1
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
    workspace = Holter.Monitoring.get_workspace!(monitor.workspace_id)
    json = 
      conn 
      |> get(~p"/api/v1/workspaces/#{workspace.slug}/monitors/#{monitor.id}")
      |> json_response(200)
    
    assert_schema(json, "MonitorResponse", ApiSpec.spec())
  end

  test "Swagger UI is accessible and points to correct spec" do
    conn = get(build_conn(), "/api/swagger")
    assert html_response(conn, 200) =~ "swagger-ui"
    # O Swagger UI usa api_spec_url.pathname = "/api/openapi" de forma dinâmica
    assert html_response(conn, 200) =~ "/api/openapi"
  end
end
