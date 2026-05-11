defmodule HolterWeb.Web.Dev.EmailPreviewLiveTest do
  use HolterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Holter.Emails.Previews

  describe "GET /dev/emails" do
    test "renders the catalogue header on the empty landing view", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dev/emails")

      assert html =~ "Email previews"
    end

    test "lists every preview entry in the sidebar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dev/emails")

      for preview <- Previews.list() do
        assert html =~ preview.label
      end
    end
  end

  describe "GET /dev/emails/:preview_key/:variant_key" do
    test "renders the registration verification preview into the HTML iframe", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/dev/emails/registration_verification/default?locale=en&view=html")

      assert html =~ ~s(<iframe)
      assert html =~ "srcdoc="
      assert html =~ "Welcome to Holter"
    end

    test "renders pt_BR copy when the locale param is pt_BR", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/dev/emails/registration_verification/default?locale=pt_BR&view=html")

      assert html =~ "Bem-vindo ao Holter"
    end

    test "switches to plain text when the view param is text", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/dev/emails/password_reset_request/default?locale=en&view=text")

      assert html =~ "Holter password reset" or html =~ "Reset your password" or
               html =~ "We received a request"
    end

    test "exposes the rendered subject in the headers view", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/dev/emails/password_changed/default?locale=en&view=headers")

      assert html =~ "Your password has been changed"
    end

    test "renders the alert_down with_root_cause variant including the root cause line", %{
      conn: conn
    } do
      {:ok, _view, html} =
        live(conn, ~p"/dev/emails/alert_down/with_root_cause?locale=en&view=html")

      assert html =~ "HTTP 500 from upstream"
    end

    test "ignores unknown preview keys and falls back to the empty landing", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dev/emails/does_not_exist/nope?locale=en&view=html")

      assert html =~ "Pick a template from the sidebar"
    end
  end

  describe "every preview × variant × locale renders without crashing" do
    test "Previews.build/3 returns a multipart email for each combination" do
      for preview <- Previews.list(),
          variant <- preview.variants,
          locale <- Previews.locales() do
        email = Previews.build(preview.key, variant.key, locale)

        assert non_empty_string?(email.subject) and non_empty_string?(email.text_body) and
                 non_empty_string?(email.html_body)
      end
    end
  end

  defp non_empty_string?(value), do: is_binary(value) and value != ""

  describe "locale switch" do
    test "select_locale patches the URL and re-renders the preview in pt_BR", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/dev/emails/registration_verification/default?locale=en&view=html")

      html =
        view
        |> form("form[phx-change=select_locale]", locale: "pt_BR")
        |> render_change()

      assert html =~ "Bem-vindo ao Holter"
    end

    test "select_view patches the URL to flip the rendering mode", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/dev/emails/registration_verification/default?locale=en&view=html")

      html = view |> element("button[phx-value-view=text]") |> render_click()

      refute html =~ ~s(<iframe)
      assert html =~ "Welcome to Holter"
    end
  end

  describe "send_to_mailbox" do
    test "delivers the current preview through the Swoosh test adapter", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/dev/emails/registration_verification/default?locale=en&view=html")

      view |> element("button", "Send to /dev/mailbox") |> render_click()

      assert_email_sent(fn email ->
        assert email.subject =~ "Verify"
      end)
    end
  end
end
