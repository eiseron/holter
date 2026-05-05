defmodule Holter.Identity.Emails.PasswordResetRequest do
  @moduledoc """
  Pure builder for the email sent when a user requests a password reset.
  Composing the email is decoupled from delivering it so the coordinator
  owns the side effect (Swoosh adapter call) and tests can assert on the
  message shape without hitting a mailer.
  """

  use Gettext, backend: HolterWeb.Gettext
  import Swoosh.Email

  def build_reset_email(user, %{url: reset_url, from: from_address}) do
    new()
    |> to(user.email)
    |> from(from_address)
    |> subject(gettext("Holter password reset"))
    |> text_body(text_body(reset_url))
  end

  defp text_body(reset_url) do
    gettext(
      "We received a request to reset the password on your Holter account.\n\n" <>
        "Follow the link below to choose a new password. " <>
        "For security, this link expires in 15 minutes and can only be used once.\n\n" <>
        "%{url}\n\n" <>
        "If you did not request a password reset, you can safely ignore this message — your current password is still valid.\n",
      url: reset_url
    )
  end
end
