defmodule HolterWeb.Api.OpenapiSpecTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  describe "GET /api/openapi" do
    test "returns 200 with the OpenAPI JSON spec without bearer auth", %{conn: conn} do
      conn = get(conn, "/api/openapi")

      assert json_response(conn, 200)["openapi"] =~ "3."
    end

    test "exposes the configured monitor paths", %{conn: conn} do
      conn = get(conn, "/api/openapi")

      assert Map.has_key?(json_response(conn, 200)["paths"], "/api/v1/monitors/{id}")
    end

    test "declares bearerAuth as the global security requirement", %{conn: conn} do
      conn = get(conn, "/api/openapi")

      assert json_response(conn, 200)["security"] == [%{"bearerAuth" => []}]
    end

    test "documents the bearerAuth security scheme as http bearer", %{conn: conn} do
      conn = get(conn, "/api/openapi")
      scheme = get_in(json_response(conn, 200), ["components", "securitySchemes", "bearerAuth"])

      assert %{"type" => "http", "scheme" => "bearer"} = scheme
    end
  end

  describe "GET /api/swagger" do
    test "returns 200 with the Swagger UI HTML without bearer auth", %{conn: conn} do
      conn = get(conn, "/api/swagger")

      assert html_response(conn, 200) =~ "Swagger UI"
    end
  end
end
