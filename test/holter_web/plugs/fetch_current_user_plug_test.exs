defmodule HolterWeb.Plugs.FetchCurrentUserPlugTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  alias HolterWeb.Plugs.FetchCurrentUserPlug

  defp init_conn(conn, session_attrs \\ %{}) do
    conn
    |> Plug.Test.init_test_session(session_attrs)
    |> Phoenix.Controller.fetch_flash([])
  end

  describe "call/2 — unauthenticated request" do
    test "halts the connection when no session token is present", %{conn: conn} do
      conn = init_conn(conn)

      assert FetchCurrentUserPlug.call(conn, []).halted
    end

    test "redirects to identity/login when no session token is present", %{conn: conn} do
      conn = init_conn(conn)
      result = FetchCurrentUserPlug.call(conn, [])

      assert redirected_to(result) =~ "/identity/login"
    end

    test "sets an error flash when no session token is present", %{conn: conn} do
      conn = init_conn(conn)
      result = FetchCurrentUserPlug.call(conn, [])

      assert Phoenix.Flash.get(result.assigns.flash, :error) =~ "logged in"
    end

    test "halts when session token does not match any user", %{conn: conn} do
      conn = init_conn(conn, %{user_token: "invalid_token_that_does_not_exist"})

      assert FetchCurrentUserPlug.call(conn, []).halted
    end

    test "redirects to identity/login when session token does not match any user", %{conn: conn} do
      conn = init_conn(conn, %{user_token: "invalid_token_that_does_not_exist"})
      result = FetchCurrentUserPlug.call(conn, [])

      assert redirected_to(result) =~ "/identity/login"
    end
  end

  describe "call/2 — authenticated request" do
    test "assigns current_user when session token is valid", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      conn = log_in_user(conn, user)
      result = FetchCurrentUserPlug.call(conn, [])

      refute result.halted
      assert result.assigns.current_user.id == user.id
    end
  end
end
