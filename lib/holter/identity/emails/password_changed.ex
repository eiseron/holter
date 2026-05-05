defmodule Holter.Identity.Emails.PasswordChanged do
  @moduledoc """
  Pure builder for the security-alert email sent after a successful
  password reset. Composing the email is decoupled from delivering it so
  the coordinator owns the side effect (Swoosh adapter call) and tests
  can assert on the message shape without hitting a mailer.
  """

  use Gettext, backend: HolterWeb.Gettext
  import Swoosh.Email

  def build_alert_email(user, %{from: from_address}) do
    new()
    |> to(user.email)
    |> from(from_address)
    |> subject(gettext("Your password has been changed"))
    |> text_body(text_body())
  end

  defp text_body do
    gettext(
      "Your Holter account password has been changed successfully.\n\n" <>
        "All active sessions on other devices have been revoked. " <>
        "You will need to sign in again on those devices using the new password.\n\n" <>
        "If you did not perform this change, contact support immediately — " <>
        "your account may be compromised.\n"
    )
  end
end
