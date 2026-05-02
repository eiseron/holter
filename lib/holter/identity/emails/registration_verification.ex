defmodule Holter.Identity.Emails.RegistrationVerification do
  @moduledoc """
  Pure builder for the email sent at the end of `Identity.register_user/1`.
  Composing the email is decoupled from delivering it so the coordinator
  owns the side effect (Swoosh adapter call) and tests can assert on the
  message shape without hitting a mailer.
  """

  use Gettext, backend: HolterWeb.Gettext
  import Swoosh.Email

  def build_verification_email(user, %{url: verification_url, from: from_address}) do
    new()
    |> to(user.email)
    |> from(from_address)
    |> subject(gettext("Verify your Holter account"))
    |> text_body(text_body(verification_url))
  end

  defp text_body(verification_url) do
    gettext(
      "Welcome to Holter.\n\n" <>
        "Click the link below to verify your email address and activate your account. " <>
        "Until you do, you can sign in but cannot create monitors or notification channels.\n\n" <>
        "%{url}\n\n" <>
        "If you did not create a Holter account, you can ignore this message.\n",
      url: verification_url
    )
  end
end
