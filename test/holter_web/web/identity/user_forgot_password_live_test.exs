defmodule HolterWeb.Web.Identity.UserForgotPasswordLiveTest do
  use HolterWeb.ConnCase, async: false

  @moduletag :guest

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Holter.Identity.Models.Token
  alias Holter.Repo

  defp drain_mailbox do
    receive do
      {:email, _} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  describe "GET /identity/forgot-password" do
    test "renders the email form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/identity/forgot-password")

      assert html =~ "Forgot your password?"
      assert html =~ ~s(name="user[email]")
    end

    test "redirects an authenticated user away from the guest flow", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      token = session_token_fixture(user)

      conn = Plug.Test.init_test_session(conn, %{user_token: token})

      assert {:error, {:redirect, %{to: redirect}}} =
               live(conn, ~p"/identity/forgot-password")

      assert redirect != "/identity/forgot-password"
    end
  end

  describe "submitting the forgot-password form" do
    test "shows the neutral confirmation flash and redirects to /identity/login (known email)",
         %{conn: conn} do
      %{user: user} = verified_user_fixture()
      drain_mailbox()
      {:ok, lv, _html} = live(conn, ~p"/identity/forgot-password")

      result =
        lv
        |> form("#forgot-password-form", user: %{"email" => user.email})
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/identity/login"}}} = result

      assert {:ok, _conn, html} = follow_redirect(result, conn)
      assert html =~ "If this email exists, you will receive instructions."
    end

    test "delivers the reset email when the address belongs to a real user", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      drain_mailbox()
      {:ok, lv, _html} = live(conn, ~p"/identity/forgot-password")

      _ = lv |> form("#forgot-password-form", user: %{"email" => user.email}) |> render_submit()

      assert_email_sent(fn email ->
        assert Enum.any?(email.to, fn {_, addr} -> addr == user.email end)
        assert email.subject =~ "password"
      end)
    end

    test "shows the same neutral flash and sends nothing for an unknown email",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/forgot-password")

      result =
        lv
        |> form("#forgot-password-form", user: %{"email" => "ghost@holter.test"})
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/identity/login"}}} = result

      assert {:ok, _conn, html} = follow_redirect(result, conn)
      assert html =~ "If this email exists, you will receive instructions."
      refute_email_sent()
    end

    test "creates no token rows for an unknown email (no enumeration via DB state)",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/forgot-password")

      _ =
        lv
        |> form("#forgot-password-form", user: %{"email" => "nobody@holter.test"})
        |> render_submit()

      assert Repo.aggregate(
               from(t in Token, where: t.type == :reset_password),
               :count
             ) == 0
    end

    test "shows a field-level error and does not redirect when email is blank",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/forgot-password")

      html =
        lv
        |> form("#forgot-password-form", user: %{"email" => ""})
        |> render_submit()

      assert html =~ "h-input-error"
      refute_email_sent()
    end
  end
end
