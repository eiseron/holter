defmodule HolterWeb.Api.IntegrationEventControllerTest do
  use HolterWeb.ConnCase, async: true

  import OpenApiSpex.TestAssertions

  alias HolterWeb.Api.ApiSpec

  setup %{conn: conn, current_user: user} do
    workspace = workspace_fixture(%{owner: user, slug: "event-ws"})
    integration = integration_fixture(workspace_id: workspace.id)
    api_spec = ApiSpec.spec()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> authed_api_conn({user, workspace})

    {:ok,
     conn: conn,
     workspace: workspace,
     integration: integration,
     api_spec: api_spec,
     current_user: user}
  end

  describe "GET /api/v1/integrations/:integration_id/events" do
    test "lists events for the integration with pagination metadata", %{
      conn: conn,
      integration: integration,
      api_spec: spec
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..3, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      conn = get(conn, ~p"/api/v1/integrations/#{integration.id}/events")
      body = json_response(conn, 200)

      assert length(body["data"]) == 3
      assert body["meta"]["page"] == 1
      assert body["meta"]["page_size"] == 25
      assert body["meta"]["total_pages"] == 1
      assert_schema(body, "IntegrationEventList", spec)
    end

    test "paginates with page and page_size query params", %{
      conn: conn,
      integration: integration
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        integration_event_fixture(integration: integration, occurred_at: DateTime.add(now, -i))
      end)

      conn =
        get(conn, ~p"/api/v1/integrations/#{integration.id}/events?page=2&page_size=3")

      body = json_response(conn, 200)

      assert length(body["data"]) == 2
      assert body["meta"]["page"] == 2
      assert body["meta"]["page_size"] == 3
      assert body["meta"]["total_pages"] == 2
    end

    test "returns empty list when no events exist", %{conn: conn, integration: integration} do
      conn = get(conn, ~p"/api/v1/integrations/#{integration.id}/events")
      body = json_response(conn, 200)

      assert body["data"] == []
      assert body["meta"]["total_pages"] == 1
    end

    test "returns 404 when integration is unknown", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/integrations/00000000-0000-0000-0000-000000000000/events")
      assert json_response(conn, 404)
    end

    test "returns 403 without read:integrations scope", %{
      integration: integration,
      workspace: ws,
      current_user: user
    } do
      narrow =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> authed_api_conn({user, ws}, scopes: ["read:monitors"])

      conn = get(narrow, ~p"/api/v1/integrations/#{integration.id}/events")
      assert json_response(conn, 403)["required_scope"] == "read:integrations"
    end
  end

  describe "GET /api/v1/integration_events/:id" do
    test "returns the event", %{conn: conn, integration: integration, api_spec: spec} do
      event = integration_event_fixture(integration: integration)

      conn = get(conn, ~p"/api/v1/integration_events/#{event.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == event.id
      assert body["data"]["integration_id"] == integration.id
      assert_schema(body, "IntegrationEventResponse", spec)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/integration_events/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end

    test "returns 403 when event belongs to another workspace's integration", %{conn: conn} do
      %{user: stranger} = verified_user_fixture()
      other_ws = workspace_fixture(%{owner: stranger})
      other_integration = integration_fixture(workspace_id: other_ws.id)
      foreign_event = integration_event_fixture(integration: other_integration)

      conn = get(conn, ~p"/api/v1/integration_events/#{foreign_event.id}")
      assert json_response(conn, 403)
    end
  end
end
