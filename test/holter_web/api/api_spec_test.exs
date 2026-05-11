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

  describe "webhook dispatch callbacks (issue #28)" do
    setup do
      spec = ApiSpec.spec()
      {:ok, spec: spec, schemas: spec.components.schemas}
    end

    test "exposes the dispatch payload schemas in components", %{schemas: schemas} do
      for name <-
            ~w(MonitorSummary IncidentSummary ChannelSummary WebhookIncidentDispatch WebhookTestPingDispatch WebhookDispatch) do
        assert Map.has_key?(schemas, name), "missing schema #{name}"
      end
    end

    test "WebhookDispatch is a oneOf union discriminated by event", %{schemas: schemas} do
      assert %OpenApiSpex.Schema{
               oneOf: variants,
               discriminator: %OpenApiSpex.Discriminator{propertyName: "event", mapping: mapping}
             } = schemas["WebhookDispatch"]

      assert length(variants) == 2
      assert Map.keys(mapping) |> Enum.sort() == ["monitor_down", "monitor_up", "test_ping"]
    end

    test "the incident dispatch variant only emits monitor_down and monitor_up", %{
      schemas: schemas
    } do
      incident = schemas["WebhookIncidentDispatch"]

      assert incident.properties.event.enum == ["monitor_down", "monitor_up"]
      assert :monitor in incident.required
      assert :incident in incident.required
    end

    test "the test ping variant emits test_ping with a channel reference", %{schemas: schemas} do
      test_ping = schemas["WebhookTestPingDispatch"]

      assert test_ping.properties.event.enum == ["test_ping"]
      assert :channel in test_ping.required
      refute :monitor in test_ping.required
      refute :incident in test_ping.required
    end

    test "MonitorSummary enumerates the runtime health_status values", %{schemas: schemas} do
      monitor = schemas["MonitorSummary"]

      assert monitor.properties.health_status.enum == [
               "up",
               "down",
               "degraded",
               "compromised",
               "unknown"
             ]
    end

    test "IncidentSummary enumerates the runtime incident types", %{schemas: schemas} do
      incident = schemas["IncidentSummary"]

      assert incident.properties.type.enum == ["downtime", "defacement", "ssl_expiry"]
    end

    test "the channel create operation declares a webhookDispatch callback", %{spec: spec} do
      path = spec.paths["/api/v1/workspaces/{workspace_slug}/webhook_channels"]

      assert %OpenApiSpex.PathItem{post: %OpenApiSpex.Operation{callbacks: callbacks}} = path
      assert Map.has_key?(callbacks, "webhookDispatch")

      callback = callbacks["webhookDispatch"]
      assert Map.has_key?(callback, "{$request.body#/url}")

      %OpenApiSpex.PathItem{
        post: %OpenApiSpex.Operation{
          requestBody: %OpenApiSpex.RequestBody{
            content: %{
              "application/json" => %OpenApiSpex.MediaType{schema: schema_ref}
            }
          },
          responses: responses
        }
      } = callback["{$request.body#/url}"]

      assert %OpenApiSpex.Reference{"$ref": "#/components/schemas/WebhookDispatch"} = schema_ref
      assert Map.keys(responses) |> Enum.sort() == ["2XX", "default"]
    end

    test "the channel update operation declares the same webhookDispatch callback", %{spec: spec} do
      path = spec.paths["/api/v1/webhook_channels/{id}"]

      assert %OpenApiSpex.PathItem{patch: %OpenApiSpex.Operation{callbacks: callbacks}} = path
      assert Map.has_key?(callbacks, "webhookDispatch")

      callback = callbacks["webhookDispatch"]
      assert Map.has_key?(callback, "{$request.body#/url}")
    end
  end
end
