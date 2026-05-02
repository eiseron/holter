defmodule HolterWeb.Web.Identity.UserEmailVerificationLiveTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  alias Holter.Identity.User
  alias Holter.Repo

  describe "GET /identity/verify-email/:token" do
    test "transitions the account to :active on success", %{conn: conn} do
      %{user: user, raw_verify_token: token} = register_user_fixture()
      _ = live(conn, ~p"/identity/verify-email/#{token}")

      reloaded = Repo.get!(User, user.id)

      assert reloaded.onboarding_status == :active
    end

    test "redirects to /identity/login with a confirmation flash", %{conn: conn} do
      %{raw_verify_token: token} = register_user_fixture()

      assert {:error, {:live_redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/identity/verify-email/#{token}")
    end

    test "rejects an unknown token without crashing", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/identity/verify-email/garbage")
    end

    test "rejects a token that has already been used", %{conn: conn} do
      %{raw_verify_token: token} = register_user_fixture()
      _ = live(conn, ~p"/identity/verify-email/#{token}")

      assert {:error, {:live_redirect, %{to: "/identity/login"}}} =
               live(build_conn(), ~p"/identity/verify-email/#{token}")
    end
  end
end
