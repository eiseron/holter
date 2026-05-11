defmodule Holter.Identity.Emails.PasswordChanged do
  @moduledoc """
  Pure builder for the security-alert email sent after a successful
  password reset. Composing the email is decoupled from delivering it so
  the coordinator owns the side effect (Swoosh adapter call) and tests
  can assert on the message shape without hitting a mailer.

  Renders both an HTML body (multipart alternative) and a plain-text body
  framed by the shared Holter email layout.
  """

  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  import Swoosh.Email

  alias Holter.Emails.{Components, Layout, Renderer}

  def build_alert_email(user, %{from: from_address}) do
    new()
    |> to(user.email)
    |> from(from_address)
    |> subject(dgettext("emails", "Your password has been changed"))
    |> text_body(plain_text())
    |> html_body(Renderer.to_html(&html/1, %{}))
  end

  def html(assigns) do
    ~H"""
    <Layout.html
      title={dgettext("emails", "Your password has been changed")}
      preheader={dgettext("emails", "Confirmation that your Holter password was just changed.")}
    >
      <h1 style="margin: 0 0 16px 0; font-size: 22px; line-height: 1.3; color: #fafafa;">
        {dgettext("emails", "Your password has been changed")}
      </h1>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext("emails", "Your Holter account password has been changed successfully.")}
      </p>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "All active sessions on other devices have been revoked. You will need to sign in again on those devices using the new password."
        )}
      </p>
      <Components.info_box variant="danger">
        {dgettext(
          "emails",
          "If you did not perform this change, contact support immediately — your account may be compromised."
        )}
      </Components.info_box>
    </Layout.html>
    """
  end

  defp plain_text do
    body =
      dgettext(
        "emails",
        "Your Holter account password has been changed successfully.\n\n" <>
          "All active sessions on other devices have been revoked. " <>
          "You will need to sign in again on those devices using the new password.\n\n" <>
          "If you did not perform this change, contact support immediately — " <>
          "your account may be compromised."
      )

    Layout.text(body)
  end
end
