defmodule Holter.Delivery.Emails.RecipientVerification do
  @moduledoc """
  Pure builder for the double opt-in email sent when an operator adds an
  address to a delivery email channel. Composing the email is decoupled
  from delivering it so the coordinator owns the side effect (Swoosh
  adapter call) and tests can assert on the message shape without hitting
  a mailer.

  Renders both an HTML body (multipart alternative) and a plain-text body
  framed by the shared Holter email layout.
  """

  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  import Swoosh.Email

  alias Holter.Emails.{Components, Layout, Renderer}

  def build_verification_email(recipient, _channel, %{url: verification_url, from: from_address}) do
    new()
    |> to(recipient.email)
    |> from(from_address)
    |> subject(dgettext("emails", "Confirm this address to receive monitoring alerts"))
    |> text_body(plain_text(verification_url))
    |> html_body(Renderer.to_html(&html/1, %{verification_url: verification_url}))
  end

  attr :verification_url, :string, required: true

  def html(assigns) do
    ~H"""
    <Layout.html
      title={dgettext("emails", "Confirm this address to receive monitoring alerts")}
      preheader={dgettext("emails", "Confirm this address to start receiving Holter alerts.")}
    >
      <h1 style="margin: 0 0 16px 0; font-size: 22px; line-height: 1.3; color: #fafafa;">
        {dgettext("emails", "Confirm this address")}
      </h1>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "Someone added this address to receive copies of monitoring alerts from a Holter service."
        )}
      </p>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "If you confirm, you will receive notifications when an external system being monitored goes down or recovers."
        )}
      </p>
      <Components.cta_button href={@verification_url}>
        {dgettext("emails", "Confirm address")}
      </Components.cta_button>
      <p style="margin: 0 0 16px 0; font-size: 13px; line-height: 1.55; color: #a6a6a6;">
        {dgettext("emails", "If the button does not work, paste this link into your browser:")}
        <br /><a href={@verification_url} style="color: #37b9ff;">{@verification_url}</a>
      </p>
      <Components.info_box variant="info">
        {dgettext(
          "emails",
          "We do not disclose what is being monitored in this email so you can decide based on whether you expected the request, not the target."
        )}
      </Components.info_box>
      <p style="margin: 0; font-size: 13px; line-height: 1.55; color: #a6a6a6;">
        {dgettext(
          "emails",
          "This link expires in 48 hours. If you did not expect this email, you can ignore it; no alerts will be sent."
        )}
      </p>
    </Layout.html>
    """
  end

  defp plain_text(verification_url) do
    body =
      dgettext(
        "emails",
        "Someone added this address to receive copies of monitoring alerts from a Holter service.\n\n" <>
          "If you confirm, you will receive notifications when an external system being monitored goes down or recovers. " <>
          "We do not disclose what is being monitored in this email so you can decide based on whether you expected the request, not the target.\n\n" <>
          "Confirm this address: %{url}\n\n" <>
          "This link expires in 48 hours. If you did not expect this email, you can ignore it; no alerts will be sent.",
        url: verification_url
      )

    Layout.text(body)
  end
end
