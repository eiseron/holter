defmodule Holter.Identity.Emails.RegistrationVerification do
  @moduledoc """
  Pure builder for the email sent at the end of `Identity.register_user/1`.
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

  def build_verification_email(user, %{url: verification_url, from: from_address}) do
    new()
    |> to(user.email)
    |> from(from_address)
    |> subject(dgettext("emails", "Verify your Holter account"))
    |> text_body(plain_text(verification_url))
    |> html_body(Renderer.to_html(&html/1, %{verification_url: verification_url}))
  end

  attr :verification_url, :string, required: true

  def html(assigns) do
    ~H"""
    <Layout.html
      title={dgettext("emails", "Verify your Holter account")}
      preheader={dgettext("emails", "Confirm your email to activate notifications and monitors.")}
    >
      <h1 style="margin: 0 0 16px 0; font-size: 22px; line-height: 1.3; color: #fafafa;">
        {dgettext("emails", "Welcome to Holter")}
      </h1>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "Click the button below to verify your email address and activate your account."
        )}
      </p>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "Until you do, you can sign in but cannot create monitors or notification channels."
        )}
      </p>
      <Components.cta_button href={@verification_url}>
        {dgettext("emails", "Verify email")}
      </Components.cta_button>
      <p style="margin: 0 0 16px 0; font-size: 13px; line-height: 1.55; color: #a6a6a6;">
        {dgettext("emails", "If the button does not work, paste this link into your browser:")}
        <br /><a href={@verification_url} style="color: #37b9ff;">{@verification_url}</a>
      </p>
      <p style="margin: 0; font-size: 13px; line-height: 1.55; color: #a6a6a6;">
        {dgettext(
          "emails",
          "If you did not create a Holter account, you can ignore this message."
        )}
      </p>
    </Layout.html>
    """
  end

  defp plain_text(verification_url) do
    body =
      dgettext(
        "emails",
        "Welcome to Holter.\n\n" <>
          "Click the link below to verify your email address and activate your account. " <>
          "Until you do, you can sign in but cannot create monitors or notification channels.\n\n" <>
          "%{url}\n\n" <>
          "If you did not create a Holter account, you can ignore this message.",
        url: verification_url
      )

    Layout.text(body)
  end
end
