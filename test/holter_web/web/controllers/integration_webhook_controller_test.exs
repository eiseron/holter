defmodule HolterWeb.Web.Integrations.IntegrationWebhookControllerTest do
  use HolterWeb.ConnCase, async: true

  describe "POST /integrations/workspaces/:workspace_slug/:provider/webhook" do
    test "returns 200 with ok true when workspace and integration exist", %{conn: conn} do
      ws = workspace_fixture()
      _integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      conn = post(conn, ~p"/integrations/workspaces/#{ws.slug}/google_ads/webhook")

      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 404 when workspace does not exist", %{conn: conn} do
      conn = post(conn, ~p"/integrations/workspaces/nonexistent/google_ads/webhook")

      assert json_response(conn, 404)["error"] == "not_found"
    end

    test "returns 404 when integration does not exist for provider", %{conn: conn} do
      ws = workspace_fixture()

      conn = post(conn, ~p"/integrations/workspaces/#{ws.slug}/slack/webhook")

      assert json_response(conn, 404)["error"] == "not_found"
    end

    test "returns 404 when provider string is unknown instead of crashing", %{conn: conn} do
      ws = workspace_fixture()

      conn = post(conn, ~p"/integrations/workspaces/#{ws.slug}/__unknown__/webhook")

      assert json_response(conn, 404)["error"] == "not_found"
    end
  end
end
