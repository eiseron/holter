defmodule HolterWeb.Web.Identity.UserLoginLiveTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  describe "GET /identity/login" do
    test "renders the sign-in form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/identity/login")

      assert html =~ "Sign in to Holter"
    end
  end

  describe "POST /identity/login" do
    test "redirects a verified user to their workspace dashboard", %{conn: conn} do
      %{user: user, workspace: workspace} = verified_user_fixture()

      conn =
        post(conn, ~p"/identity/login", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/monitoring/workspaces/#{workspace.slug}/monitors"
    end

    test "stamps a session cookie under :user_token on success", %{conn: conn} do
      %{user: user} = verified_user_fixture()

      conn =
        post(conn, ~p"/identity/login", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
    end

    test "redirects back to /identity/login with a flash on wrong password", %{conn: conn} do
      %{user: user} = verified_user_fixture()

      conn =
        post(conn, ~p"/identity/login", %{
          "user" => %{"email" => user.email, "password" => "Wrong-Password-1!"}
        })

      assert redirected_to(conn) == "/identity/login"
    end

    test "exposes a neutral flash on wrong password (no enumeration)", %{conn: conn} do
      %{user: user} = verified_user_fixture()

      conn =
        post(conn, ~p"/identity/login", %{
          "user" => %{"email" => user.email, "password" => "Wrong-Password-1!"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "responds the same way to an unknown email (no enumeration)", %{conn: conn} do
      conn =
        post(conn, ~p"/identity/login", %{
          "user" => %{"email" => "ghost@holter.test", "password" => "Anything-1234!"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end
  end

  describe "DELETE /identity/logout" do
    test "clears the session and redirects to /identity/login", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      token = session_token_fixture(user)

      conn =
        conn
        |> Plug.Test.init_test_session(%{user_token: token})
        |> delete(~p"/identity/logout")

      assert redirected_to(conn) == "/identity/login"
    end

    test "drops the :user_token from the session after logout", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      token = session_token_fixture(user)

      conn =
        conn
        |> Plug.Test.init_test_session(%{user_token: token})
        |> delete(~p"/identity/logout")

      assert get_session(conn, :user_token) == nil
    end
  end
end
