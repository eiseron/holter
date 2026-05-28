defmodule HolterWeb.Web.Identity.UserResetPasswordLiveTest do
  use HolterWeb.ConnCase, async: false

  @moduletag :guest

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Eiseron.Identity.Password
  alias Holter.Identity
  alias Holter.Identity.Models.User
  alias Holter.Identity.Tokens
  alias Holter.Repo

  defp pepper, do: Application.fetch_env!(:holter, :identity)[:pepper]

  defp drain_mailbox do
    receive do
      {:email, _} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  defp setup_reset_token(_) do
    %{user: user} = verified_user_fixture()
    {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)
    drain_mailbox()
    {:ok, user: user, token: plaintext}
  end

  describe "GET /identity/reset-password/:token" do
    test "renders the password + confirmation form regardless of token validity",
         %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/identity/reset-password/any-bogus-token")

      assert html =~ "Set a new password"
      assert html =~ ~s(name="user[password]")
      assert html =~ ~s(name="user[password_confirmation]")
    end

    test "redirects an authenticated user away from the guest flow", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      token = session_token_fixture(user)

      conn = Plug.Test.init_test_session(conn, %{user_token: token})

      assert {:error, {:redirect, %{to: redirect}}} =
               live(conn, ~p"/identity/reset-password/some-token")

      assert redirect != "/identity/reset-password/some-token"
    end
  end

  describe "submitting a strong password with a valid token" do
    setup :setup_reset_token

    test "redirects to /identity/login with a success flash", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      result =
        lv
        |> form("#reset-password-form",
          user: %{
            "password" => "Br4nd-NewP4ssword!",
            "password_confirmation" => "Br4nd-NewP4ssword!"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/identity/login"}}} = result

      assert {:ok, _conn, html} = follow_redirect(result, conn)
      assert html =~ "password has been updated"
    end

    test "actually updates the user's hashed password", %{conn: conn, user: user, token: token} do
      original_hash = user.hashed_password
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      _ =
        lv
        |> form("#reset-password-form",
          user: %{
            "password" => "Br4nd-NewP4ssword!",
            "password_confirmation" => "Br4nd-NewP4ssword!"
          }
        )
        |> render_submit()

      reloaded = Repo.get!(User, user.id)
      refute reloaded.hashed_password == original_hash
      assert Password.verify("Br4nd-NewP4ssword!", reloaded.hashed_password, pepper())
    end

    test "kills active sessions on other devices (Soberania da Sessão)",
         %{conn: conn, user: user, token: token} do
      other_device = session_token_fixture(user)
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      _ =
        lv
        |> form("#reset-password-form",
          user: %{
            "password" => "Br4nd-NewP4ssword!",
            "password_confirmation" => "Br4nd-NewP4ssword!"
          }
        )
        |> render_submit()

      assert Identity.fetch_user_by_session_token(other_device) == nil
    end

    test "delivers the password-changed alert to the user", %{
      conn: conn,
      user: user,
      token: token
    } do
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      _ =
        lv
        |> form("#reset-password-form",
          user: %{
            "password" => "Br4nd-NewP4ssword!",
            "password_confirmation" => "Br4nd-NewP4ssword!"
          }
        )
        |> render_submit()

      assert_email_sent(fn email ->
        assert Enum.any?(email.to, fn {_, addr} -> addr == user.email end)
        assert email.subject == "Your password has been changed"
      end)
    end
  end

  describe "submitting with an invalid or expired token" do
    test "redirects to /identity/forgot-password with an error flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/not-a-real-token")

      result =
        lv
        |> form("#reset-password-form",
          user: %{
            "password" => "Br4nd-NewP4ssword!",
            "password_confirmation" => "Br4nd-NewP4ssword!"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/identity/forgot-password"}}} = result

      assert {:ok, _conn, html} = follow_redirect(result, conn)
      assert html =~ "invalid"
    end

    test "does not deliver the alert email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/not-a-real-token")

      _ =
        lv
        |> form("#reset-password-form",
          user: %{
            "password" => "Br4nd-NewP4ssword!",
            "password_confirmation" => "Br4nd-NewP4ssword!"
          }
        )
        |> render_submit()

      refute_email_sent()
    end
  end

  describe "submitting a weak password with a valid token" do
    setup :setup_reset_token

    test "renders inline strength errors and does not redirect", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      html =
        lv
        |> form("#reset-password-form",
          user: %{"password" => "weak", "password_confirmation" => "weak"}
        )
        |> render_submit()

      assert html =~ "12 characters"
    end

    test "leaves the password unchanged", %{conn: conn, user: user, token: token} do
      original_hash = user.hashed_password
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      _ =
        lv
        |> form("#reset-password-form",
          user: %{"password" => "weak", "password_confirmation" => "weak"}
        )
        |> render_submit()

      assert Repo.get!(User, user.id).hashed_password == original_hash
    end

    test "does not deliver the alert email", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      _ =
        lv
        |> form("#reset-password-form",
          user: %{"password" => "weak", "password_confirmation" => "weak"}
        )
        |> render_submit()

      refute_email_sent()
    end
  end

  describe "submitting with mismatched password confirmation" do
    setup :setup_reset_token

    test "renders an inline error and does not change the password",
         %{conn: conn, user: user, token: token} do
      original_hash = user.hashed_password
      {:ok, lv, _html} = live(conn, ~p"/identity/reset-password/#{token}")

      html =
        lv
        |> form("#reset-password-form",
          user: %{
            "password" => "Br4nd-NewP4ssword!",
            "password_confirmation" => "Different-One-1!"
          }
        )
        |> render_submit()

      assert html =~ "h-input-error"
      assert Repo.get!(User, user.id).hashed_password == original_hash
    end
  end
end
