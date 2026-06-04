defmodule HolterWeb.Api.IntegrationRuleControllerTest do
  use HolterWeb.ConnCase, async: true

  import OpenApiSpex.TestAssertions

  alias Holter.Integrations
  alias HolterWeb.Api.ApiSpec

  setup %{conn: conn, current_user: user} do
    workspace = workspace_fixture(%{owner: user, slug: "rule-ws"})
    integration = integration_fixture(workspace_id: workspace.id)
    monitor = monitor_fixture(workspace_id: workspace.id)
    api_spec = ApiSpec.spec()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> authed_api_conn({user, workspace})

    {:ok,
     conn: conn,
     workspace: workspace,
     integration: integration,
     monitor: monitor,
     api_spec: api_spec,
     current_user: user}
  end

  defp json_post(conn, path, body), do: post(conn, path, Jason.encode!(body))
  defp json_patch(conn, path, body), do: patch(conn, path, Jason.encode!(body))

  describe "GET /api/v1/integrations/:integration_id/rules" do
    test "lists rules for the integration", %{
      conn: conn,
      integration: integration,
      monitor: monitor,
      api_spec: spec
    } do
      _ = integration_rule_fixture(integration: integration, monitor: monitor)

      conn = get(conn, ~p"/api/v1/integrations/#{integration.id}/rules")
      body = json_response(conn, 200)

      assert %{"data" => [_]} = body
      assert_schema(body, "IntegrationRuleList", spec)
    end

    test "returns empty list when integration has no rules", %{
      conn: conn,
      integration: integration
    } do
      conn = get(conn, ~p"/api/v1/integrations/#{integration.id}/rules")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 404 when integration does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/integrations/00000000-0000-0000-0000-000000000000/rules")
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
        |> authed_api_conn({user, ws}, scopes: ["write:integrations"])

      conn = get(narrow, ~p"/api/v1/integrations/#{integration.id}/rules")
      assert json_response(conn, 403)["required_scope"] == "read:integrations"
    end
  end

  describe "POST /api/v1/integrations/:integration_id/rules" do
    test "creates a rule and returns 201", %{
      conn: conn,
      integration: integration,
      monitor: monitor,
      api_spec: spec
    } do
      body = %{
        monitor_id: monitor.id,
        event_type: "incident_opened",
        action: "pause_campaign",
        target_id: "gads-7"
      }

      conn = json_post(conn, ~p"/api/v1/integrations/#{integration.id}/rules", body)
      resp = json_response(conn, 201)

      assert resp["data"]["target_id"] == "gads-7"
      assert resp["data"]["integration_id"] == integration.id
      assert resp["data"]["target_type"] == "campaign"
      assert_schema(resp, "IntegrationRuleResponse", spec)
    end

    test "returns 422 when monitor_id is missing", %{conn: conn, integration: integration} do
      conn =
        json_post(conn, ~p"/api/v1/integrations/#{integration.id}/rules", %{
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-x"
        })

      assert json_response(conn, 422)
    end

    test "returns 404 when integration is unknown", %{conn: conn, monitor: monitor} do
      conn =
        json_post(
          conn,
          ~p"/api/v1/integrations/00000000-0000-0000-0000-000000000000/rules",
          %{
            monitor_id: monitor.id,
            event_type: "incident_opened",
            action: "pause_campaign",
            target_id: "x"
          }
        )

      assert json_response(conn, 404)
    end

    test "requires write:integrations scope", %{
      integration: integration,
      monitor: monitor,
      workspace: ws,
      current_user: user
    } do
      narrow =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> authed_api_conn({user, ws}, scopes: ["read:integrations"])

      conn =
        json_post(narrow, ~p"/api/v1/integrations/#{integration.id}/rules", %{
          monitor_id: monitor.id,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "x"
        })

      assert json_response(conn, 403)["required_scope"] == "write:integrations"
    end

    test "returns 404 when monitor_id belongs to another workspace", %{
      conn: conn,
      integration: integration
    } do
      %{user: stranger} = verified_user_fixture()
      stranger_ws = workspace_fixture(owner: stranger)
      foreign_monitor = monitor_fixture(workspace_id: stranger_ws.id)

      conn =
        json_post(conn, ~p"/api/v1/integrations/#{integration.id}/rules", %{
          monitor_id: foreign_monitor.id,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-evil"
        })

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/rules/:id" do
    test "returns the rule", %{
      conn: conn,
      integration: integration,
      monitor: monitor,
      api_spec: spec
    } do
      rule = integration_rule_fixture(integration: integration, monitor: monitor)

      conn = get(conn, ~p"/api/v1/rules/#{rule.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == rule.id
      assert_schema(body, "IntegrationRuleResponse", spec)
    end

    test "returns 404 for unknown rule", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/rules/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/rules/:id" do
    test "updates target_id", %{
      conn: conn,
      integration: integration,
      monitor: monitor,
      api_spec: spec
    } do
      rule = integration_rule_fixture(integration: integration, monitor: monitor)

      conn = json_patch(conn, ~p"/api/v1/rules/#{rule.id}", %{target_id: "new-target"})
      body = json_response(conn, 200)

      assert body["data"]["target_id"] == "new-target"
      assert_schema(body, "IntegrationRuleResponse", spec)
    end

    test "returns 422 for invalid action", %{
      conn: conn,
      integration: integration,
      monitor: monitor
    } do
      rule = integration_rule_fixture(integration: integration, monitor: monitor)

      conn = json_patch(conn, ~p"/api/v1/rules/#{rule.id}", %{action: "does_not_exist"})

      assert json_response(conn, 422)
    end

    test "returns 404 for unknown rule", %{conn: conn} do
      conn =
        json_patch(conn, ~p"/api/v1/rules/00000000-0000-0000-0000-000000000000", %{
          target_id: "x"
        })

      assert json_response(conn, 404)
    end

    test "rejects re-pointing monitor_id via PATCH and keeps the original monitor", %{
      conn: conn,
      integration: integration,
      monitor: monitor
    } do
      rule = integration_rule_fixture(integration: integration, monitor: monitor)

      %{user: stranger} = verified_user_fixture()
      stranger_ws = workspace_fixture(owner: stranger)
      foreign_monitor = monitor_fixture(workspace_id: stranger_ws.id)

      patched = json_patch(conn, ~p"/api/v1/rules/#{rule.id}", %{monitor_id: foreign_monitor.id})

      assert json_response(patched, 422)

      reget = get(conn, ~p"/api/v1/rules/#{rule.id}")
      assert json_response(reget, 200)["data"]["monitor_id"] == monitor.id
    end
  end

  describe "DELETE /api/v1/rules/:id" do
    test "deletes the rule and returns 204", %{
      conn: conn,
      integration: integration,
      monitor: monitor
    } do
      rule = integration_rule_fixture(integration: integration, monitor: monitor)

      conn = delete(conn, ~p"/api/v1/rules/#{rule.id}")

      assert conn.status == 204
      assert {:error, :not_found} = Integrations.get_integration_rule(rule.id)
    end

    test "returns 404 for unknown rule", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/rules/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "cross-workspace isolation on /api/v1/rules/:id" do
    setup do
      %{user: stranger} = verified_user_fixture()
      stranger_ws = workspace_fixture(owner: stranger)
      stranger_integration = integration_fixture(workspace_id: stranger_ws.id)
      stranger_monitor = monitor_fixture(workspace_id: stranger_ws.id)

      rule =
        integration_rule_fixture(
          integration: stranger_integration,
          monitor: stranger_monitor
        )

      %{foreign_rule: rule}
    end

    test "GET returns 403 for a rule in another workspace", %{conn: conn, foreign_rule: rule} do
      conn = get(conn, ~p"/api/v1/rules/#{rule.id}")
      assert json_response(conn, 403)
    end

    test "PATCH returns 403 for a rule in another workspace", %{conn: conn, foreign_rule: rule} do
      conn = json_patch(conn, ~p"/api/v1/rules/#{rule.id}", %{target_id: "x"})
      assert json_response(conn, 403)
    end

    test "DELETE returns 403 for a rule in another workspace", %{conn: conn, foreign_rule: rule} do
      conn = delete(conn, ~p"/api/v1/rules/#{rule.id}")
      assert json_response(conn, 403)
    end
  end
end
