defmodule HolterWeb.Plugs.IntegrationOAuthPlugTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Plugs.IntegrationOAuthPlug

  setup %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :phoenix_endpoint, HolterWeb.Endpoint)
    %{conn: conn}
  end

  defp sign_state(claims) do
    Phoenix.Token.sign(HolterWeb.Endpoint, "integrations_oauth_state", claims)
  end

  defp sign_state_expired(claims) do
    Phoenix.Token.sign(
      HolterWeb.Endpoint,
      "integrations_oauth_state",
      claims,
      signed_at: System.system_time(:second) - 400
    )
  end

  describe "call/2 with valid state token" do
    test "assigns oauth_state_claims when state and provider match", %{conn: conn} do
      ws = workspace_fixture()
      state = sign_state(%{workspace_id: ws.id, user_id: "user-1", provider: "slack"})

      result_conn =
        conn
        |> Map.put(:params, %{"state" => state, "provider" => "slack"})
        |> IntegrationOAuthPlug.call([])

      assert result_conn.assigns.oauth_state_claims.workspace_id == ws.id
      refute result_conn.halted
    end
  end

  describe "call/2 with provider mismatch" do
    test "halts with 400 when state provider differs from route provider", %{conn: conn} do
      ws = workspace_fixture()
      state = sign_state(%{workspace_id: ws.id, user_id: "user-1", provider: "google_ads"})

      result_conn =
        conn
        |> Map.put(:params, %{"state" => state, "provider" => "slack"})
        |> IntegrationOAuthPlug.call([])

      assert result_conn.halted
      assert result_conn.status == 400
    end
  end

  describe "call/2 with expired state" do
    test "halts with 400 when state token is past max age", %{conn: conn} do
      ws = workspace_fixture()
      state = sign_state_expired(%{workspace_id: ws.id, user_id: "user-1", provider: "slack"})

      result_conn =
        conn
        |> Map.put(:params, %{"state" => state, "provider" => "slack"})
        |> IntegrationOAuthPlug.call([])

      assert result_conn.halted
      assert result_conn.status == 400
    end
  end

  describe "call/2 with invalid state" do
    test "halts with 400 when state token is tampered", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"state" => "not.valid.token", "provider" => "slack"})
        |> IntegrationOAuthPlug.call([])

      assert result_conn.halted
      assert result_conn.status == 400
    end
  end

  describe "call/2 with missing params" do
    test "halts with 400 when state param is absent", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "slack"})
        |> IntegrationOAuthPlug.call([])

      assert result_conn.halted
      assert result_conn.status == 400
    end
  end
end
