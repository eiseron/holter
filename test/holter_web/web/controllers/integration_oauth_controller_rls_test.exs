defmodule HolterWeb.Web.Integrations.IntegrationOAuthControllerRlsTest do
  @moduledoc """
  Exercises the OAuth controller under the `holter_app` Postgres role
  with RLS enforced. The default `IntegrationOAuthControllerTest` runs
  under the superuser sandbox (BYPASSRLS), so a regression that drops
  the tenant stamp from the request path would pass there while the
  callback INSERT and the disconnect DELETE silently fail in production.

  The controller stamps the tenant via `HolterWeb.ControllerTenancy`
  (keyed on `:current_workspace`, assigned by
  `HolterWeb.Plugs.AssignIntegrationWorkspace`). If that boundary is
  removed, the assertions below flip: the callback INSERT is rejected
  by the `integrations` WITH CHECK policy and the disconnect SELECT
  returns no row.
  """

  use HolterWeb.RLSConnCase

  import Mox

  alias Holter.Integrations
  alias Holter.Repo.Tenant

  setup :verify_on_exit!

  setup do
    on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)
    :ok
  end

  describe "GET /integrations/:provider/callback under holter_app" do
    test "persists the integration when the action is tenant-stamped", %{
      conn: conn,
      current_workspace: ws
    } do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      expect(Holter.Integrations.ProviderMock, :handle_callback, fn _params, _state ->
        {:ok, %{"access_token" => "tok_rls"}}
      end)

      state = build_state_token(ws.id, "slack")

      setup_app_role()

      conn = get(conn, ~p"/integrations/slack/callback?code=auth_code&state=#{state}")

      assert redirected_to(conn) =~ "/identity/workspaces/#{ws.slug}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "connected"

      persisted =
        Tenant.with_workspace!(ws.id, fn -> Integrations.list_integrations(ws.id) end)

      assert [%{provider: :slack}] = persisted
    end
  end

  describe "DELETE /integrations/workspaces/:workspace_slug/:id under holter_app" do
    test "deletes the integration when the action is tenant-stamped", %{
      conn: conn,
      current_workspace: ws
    } do
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      setup_app_role()

      conn = delete(conn, ~p"/integrations/workspaces/#{ws.slug}/#{integration.id}")

      assert redirected_to(conn) =~ "/identity/workspaces/#{ws.slug}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "disconnected"

      remaining =
        Tenant.with_workspace!(ws.id, fn -> Integrations.list_integrations(ws.id) end)

      assert remaining == []
    end
  end

  defp build_state_token(workspace_id, provider) do
    name =
      provider
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)

    Phoenix.Token.sign(HolterWeb.Endpoint, "integrations_oauth_state", %{
      workspace_id: workspace_id,
      user_id: "user-1",
      provider: provider,
      name: name
    })
  end
end
