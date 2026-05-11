defmodule Holter.Identity.Emails.PasswordResetRequest do
  @moduledoc """
  Pure builder for the email sent when a user requests a password reset.
  Composing the email is decoupled from delivering it so the coordinator
  owns the side effect (Swoosh adapter call) and tests can assert on the
  message shape without hitting a mailer.

  Renders both an HTML body (multipart alternative) and a plain-text body
  framed by the shared Holter email layout.
  """

  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  import Swoosh.Email

  alias Holter.Emails.{Components, Layout, Renderer}

  def build_reset_email(user, %{url: reset_url, from: from_address}) do
    new()
    |> to(user.email)
    |> from(from_address)
    |> subject(dgettext("emails", "Holter password reset"))
    |> text_body(plain_text(reset_url))
    |> html_body(Renderer.to_html(&html/1, %{reset_url: reset_url}))
  end

  attr :reset_url, :string, required: true

  def html(assigns) do
    ~H"""
    <Layout.html
      title={dgettext("emails", "Holter password reset")}
      preheader={dgettext("emails", "Pick a new password. The link expires in 15 minutes.")}
    >
      <h1 style="margin: 0 0 16px 0; font-size: 22px; line-height: 1.3; color: #fafafa;">
        {dgettext("emails", "Reset your password")}
      </h1>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "We received a request to reset the password on your Holter account."
        )}
      </p>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "Click the button below to choose a new password. For security, this link expires in 15 minutes and can only be used once."
        )}
      </p>
      <Components.cta_button href={@reset_url}>
        {dgettext("emails", "Choose a new password")}
      </Components.cta_button>
      <p style="margin: 0 0 16px 0; font-size: 13px; line-height: 1.55; color: #a6a6a6;">
        {dgettext("emails", "If the button does not work, paste this link into your browser:")}
        <br /><a href={@reset_url} style="color: #37b9ff;">{@reset_url}</a>
      </p>
      <Components.info_box variant="warning">
        {dgettext(
          "emails",
          "If you did not request a password reset, you can safely ignore this message — your current password is still valid."
        )}
      </Components.info_box>
    </Layout.html>
    """
  end

  defp plain_text(reset_url) do
    body =
      dgettext(
        "emails",
        "We received a request to reset the password on your Holter account.\n\n" <>
          "Follow the link below to choose a new password. " <>
          "For security, this link expires in 15 minutes and can only be used once.\n\n" <>
          "%{url}\n\n" <>
          "If you did not request a password reset, you can safely ignore this message — your current password is still valid.",
        url: reset_url
      )

    Layout.text(body)
  end
end
