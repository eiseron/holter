defmodule HolterWeb.Plugs.ImpersonationPlugTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  alias HolterWeb.Plugs.ImpersonationPlug

  describe "call/2" do
    test "assigns nil when no impersonator_token in session", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> ImpersonationPlug.call([])

      assert conn.assigns.impersonator_email == nil
    end

    test "assigns the admin email when impersonator_token is valid", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      admin_token = Holter.IdentityFixtures.session_token_fixture(admin_user)

      conn =
        conn
        |> Plug.Test.init_test_session(%{impersonator_token: admin_token})
        |> ImpersonationPlug.call([])

      assert conn.assigns.impersonator_email == admin_user.email
    end

    test "assigns nil when impersonator_token is invalid/expired", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{impersonator_token: "invalid_token_value"})
        |> ImpersonationPlug.call([])

      assert conn.assigns.impersonator_email == nil
    end
  end
end
