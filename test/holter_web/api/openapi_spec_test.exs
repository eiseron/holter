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

  describe "webhook dispatch callbacks (issue #28)" do
    test "the channel create operation serializes the webhookDispatch callback", %{conn: conn} do
      json = conn |> get("/api/openapi") |> json_response(200)

      callback =
        get_in(json, [
          "paths",
          "/api/v1/workspaces/{workspace_slug}/webhook_channels",
          "post",
          "callbacks",
          "webhookDispatch"
        ])

      assert is_map(callback)
      assert Map.has_key?(callback, "{$request.body#/url}")

      schema_ref =
        get_in(callback, [
          "{$request.body#/url}",
          "post",
          "requestBody",
          "content",
          "application/json",
          "schema",
          "$ref"
        ])

      assert schema_ref == "#/components/schemas/WebhookDispatch"
    end

    test "the channel update operation serializes the webhookDispatch callback", %{conn: conn} do
      json = conn |> get("/api/openapi") |> json_response(200)

      callback =
        get_in(json, [
          "paths",
          "/api/v1/webhook_channels/{id}",
          "patch",
          "callbacks",
          "webhookDispatch"
        ])

      assert is_map(callback)
      assert Map.has_key?(callback, "{$request.body#/url}")
    end

    test "the spec publishes a WebhookDispatch schema discriminated by event", %{conn: conn} do
      json = conn |> get("/api/openapi") |> json_response(200)
      schema = get_in(json, ["components", "schemas", "WebhookDispatch"])

      assert %{"oneOf" => variants, "discriminator" => %{"propertyName" => "event"}} = schema
      assert length(variants) == 2
    end
  end
end
