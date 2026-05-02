defmodule HolterWeb.Web.Identity.UserRegistrationLiveTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  defp valid_signup_form_params(overrides \\ %{}) do
    Enum.into(overrides, %{
      "email" => "newcomer-#{System.unique_integer([:positive])}@holter.test",
      "password" => "Holter-Foundation-1!",
      "terms_accepted" => "true"
    })
  end

  describe "GET /identity/new" do
    test "renders the signup form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/identity/new")

      assert html =~ "Create your Holter account"
    end

    test "shows the password strength help text", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/identity/new")

      assert html =~ "12 characters"
    end
  end

  describe "submitting the form" do
    test "redirects to /identity/login after a successful signup", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/new")

      assert {:error, {:live_redirect, %{to: "/identity/login"}}} =
               lv
               |> form("#signup-form", user: valid_signup_form_params())
               |> render_submit()
    end

    test "delivers the verification email on success", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/new")
      params = valid_signup_form_params(%{"email" => "verify-me@holter.test"})

      _ = lv |> form("#signup-form", user: params) |> render_submit()

      assert_email_sent(to: "verify-me@holter.test")
    end

    test "blocks submission when the terms checkbox is not accepted", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/new")

      params = valid_signup_form_params() |> Map.delete("terms_accepted")

      html =
        lv
        |> form("#signup-form", user: params)
        |> render_submit()

      assert html =~ "h-input-error"
    end

    test "shows a field-level error when the password is too weak", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/identity/new")

      html =
        lv
        |> form("#signup-form", user: valid_signup_form_params(%{"password" => "weak"}))
        |> render_submit()

      assert html =~ "12 characters"
    end

    test "shows a field-level error when the email is already taken", %{conn: conn} do
      {:ok, _lv, _html} = live(conn, ~p"/identity/new")
      attrs = valid_signup_form_params(%{"email" => "taken@holter.test"})
      {:ok, lv1, _} = live(conn, ~p"/identity/new")
      _ = lv1 |> form("#signup-form", user: attrs) |> render_submit()

      {:ok, lv2, _} = live(build_conn(), ~p"/identity/new")
      html = lv2 |> form("#signup-form", user: attrs) |> render_submit()

      assert html =~ "has already been taken"
    end
  end
end
