defmodule HolterWeb.Web.Integrations.IntegrationOAuthControllerTest do
  use HolterWeb.ConnCase, async: false

  import Mox
  import Ecto.Query, only: [from: 2]

  alias Holter.Integrations
  alias Holter.Integrations.Models.IntegrationAuditLog
  alias Holter.Repo

  setup :verify_on_exit!

  defp audit_entries(action) do
    Repo.all(from a in IntegrationAuditLog, where: a.action == ^action)
  end

  setup do
    on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)
  end

  describe "GET /integrations/workspaces/:workspace_slug/:provider/connect" do
    test "redirects to the provider OAuth URL", %{conn: conn, current_workspace: ws} do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      expect(Holter.Integrations.ProviderMock, :oauth_url, fn _workspace_id, _state ->
        {:ok, "https://provider.example.com/oauth/authorize?client_id=test"}
      end)

      conn = get(conn, ~p"/integrations/workspaces/#{ws.slug}/slack/connect")

      assert redirected_to(conn) =~ "https://provider.example.com/oauth/authorize"
    end

    test "returns 404 when workspace does not exist", %{conn: conn} do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      conn = get(conn, ~p"/integrations/workspaces/nonexistent-ws/slack/connect")

      assert json_response(conn, 404)["error"] == "workspace not found"
    end

    test "returns 404 when provider string is unknown", %{conn: conn, current_workspace: ws} do
      conn = get(conn, ~p"/integrations/workspaces/#{ws.slug}/not_a_provider/connect")

      assert json_response(conn, 404)["error"] == "unknown provider"
    end

    test "returns 422 when provider is known but has no implementation", %{
      conn: conn,
      current_workspace: ws
    } do
      conn = get(conn, ~p"/integrations/workspaces/#{ws.slug}/google_ads/connect")

      assert json_response(conn, 422)["error"] == "provider not available"
    end

    test "returns 403 when user is not a member of the workspace", %{conn: conn} do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      %{user: other_user} = verified_user_fixture()
      other_ws = workspace_fixture(owner: other_user)

      conn = get(conn, ~p"/integrations/workspaces/#{other_ws.slug}/slack/connect")

      assert json_response(conn, 403)["error"] == "forbidden"
    end

    test "returns 403 when user is a member but not an admin of the workspace", %{conn: conn} do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      {member_user, ws} = workspace_with_role(:member)
      member_conn = log_in_user(conn, member_user)

      member_conn = get(member_conn, ~p"/integrations/workspaces/#{ws.slug}/slack/connect")

      assert json_response(member_conn, 403)["error"] == "forbidden"
    end

    test "returns 502 when provider OAuth URL is unavailable", %{
      conn: conn,
      current_workspace: ws
    } do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      expect(Holter.Integrations.ProviderMock, :oauth_url, fn _workspace_id, _state ->
        {:error, :timeout}
      end)

      conn = get(conn, ~p"/integrations/workspaces/#{ws.slug}/slack/connect")

      assert json_response(conn, 502)["error"] == "provider unavailable"
    end
  end

  describe "GET /integrations/:provider/callback" do
    test "redirects to workspace settings on successful exchange", %{
      conn: conn,
      current_workspace: ws
    } do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      expect(Holter.Integrations.ProviderMock, :handle_callback, fn _params, _state ->
        {:ok, %{"access_token" => "tok123"}}
      end)

      state = build_state_token(ws.id, "slack")
      callback_conn = get(conn, ~p"/integrations/slack/callback?code=auth_code&state=#{state}")

      assert redirected_to(callback_conn) =~ "/integrations/workspaces/#{ws.slug}"
      assert Phoenix.Flash.get(callback_conn.assigns.flash, :info) =~ "connected"
    end

    test "redirects with error flash when provider callback fails", %{
      conn: conn,
      current_workspace: ws
    } do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      expect(Holter.Integrations.ProviderMock, :handle_callback, fn _params, _state ->
        {:error, :invalid_code}
      end)

      state = build_state_token(ws.id, "slack")
      callback_conn = get(conn, ~p"/integrations/slack/callback?code=bad_code&state=#{state}")

      assert redirected_to(callback_conn) =~ "/integrations/workspaces"
      assert Phoenix.Flash.get(callback_conn.assigns.flash, :error) =~ "Failed to connect"
    end

    test "halts with 400 when state token is expired", %{conn: conn, current_workspace: ws} do
      expired_state =
        Phoenix.Token.sign(
          HolterWeb.Endpoint,
          "integrations_oauth_state",
          %{workspace_id: ws.id, user_id: "user-1", provider: "slack"},
          signed_at: System.system_time(:second) - 400
        )

      callback_conn =
        get(conn, ~p"/integrations/slack/callback?code=auth_code&state=#{expired_state}")

      assert callback_conn.status == 400
    end

    test "halts with 400 when state token provider mismatches route provider", %{
      conn: conn,
      current_workspace: ws
    } do
      state = build_state_token(ws.id, "google_ads")

      callback_conn = get(conn, ~p"/integrations/slack/callback?code=auth_code&state=#{state}")

      assert callback_conn.status == 400
    end
  end

  describe "GET /integrations/:provider/callback — audit logging" do
    test "creates an integrations.connected audit entry on successful callback", %{
      conn: conn,
      current_workspace: ws,
      current_user: user
    } do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      expect(Holter.Integrations.ProviderMock, :handle_callback, fn _params, _state ->
        {:ok, %{"access_token" => "tok123"}}
      end)

      state = build_state_token(ws.id, "slack")
      get(conn, ~p"/integrations/slack/callback?code=auth_code&state=#{state}")

      [entry] = audit_entries("integrations.connected")
      assert entry.actor_id == user.id
    end

    test "does not create an audit entry when callback fails", %{
      conn: conn,
      current_workspace: ws
    } do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      expect(Holter.Integrations.ProviderMock, :handle_callback, fn _params, _state ->
        {:error, :invalid_code}
      end)

      state = build_state_token(ws.id, "slack")
      get(conn, ~p"/integrations/slack/callback?code=bad_code&state=#{state}")

      assert audit_entries("integrations.connected") == []
    end
  end

  describe "DELETE /integrations/workspaces/:workspace_slug/:id" do
    test "disconnects and redirects to workspace settings", %{conn: conn, current_workspace: ws} do
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      conn = delete(conn, ~p"/integrations/workspaces/#{ws.slug}/#{integration.id}")

      assert redirected_to(conn) =~ "/integrations/workspaces/#{ws.slug}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "disconnected"
      assert {:error, :not_found} = Integrations.get_integration(integration.id)
    end

    test "creates an integrations.disconnected audit entry on successful disconnect", %{
      conn: conn,
      current_workspace: ws,
      current_user: user
    } do
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      delete(conn, ~p"/integrations/workspaces/#{ws.slug}/#{integration.id}")

      [entry] = audit_entries("integrations.disconnected")
      assert entry.actor_id == user.id
    end

    test "redirects with error flash when integration belongs to different workspace", %{
      conn: conn,
      current_workspace: ws
    } do
      other_ws = workspace_fixture()
      integration = integration_fixture(workspace_id: other_ws.id, provider: :google_ads)

      conn = delete(conn, ~p"/integrations/workspaces/#{ws.slug}/#{integration.id}")

      assert redirected_to(conn) =~ "/integrations/workspaces/#{ws.slug}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Could not disconnect"
    end

    test "redirects with error flash when workspace does not exist", %{conn: conn} do
      conn = delete(conn, ~p"/integrations/workspaces/nonexistent/#{Ecto.UUID.generate()}")

      assert redirected_to(conn) =~ "/integrations/workspaces/nonexistent"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Could not disconnect"
    end

    test "redirects with permission error flash when user is not an admin of the workspace", %{
      conn: conn
    } do
      %{user: other_user} = verified_user_fixture()
      other_ws = workspace_fixture(owner: other_user)

      conn = delete(conn, ~p"/integrations/workspaces/#{other_ws.slug}/#{Ecto.UUID.generate()}")

      assert redirected_to(conn) =~ "/integrations/workspaces/#{other_ws.slug}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "permission"
    end
  end

  defp build_state_token(workspace_id, provider, name \\ nil) do
    default =
      provider
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)

    Phoenix.Token.sign(HolterWeb.Endpoint, "integrations_oauth_state", %{
      workspace_id: workspace_id,
      user_id: "user-1",
      provider: provider,
      name: name || default
    })
  end
end
