defmodule Holter.Delivery.Emails.RecipientVerification do
  @moduledoc false

  import Swoosh.Email

  def build_verification_email(recipient, channel, %{url: verification_url, from: from_address}) do
    new()
    |> to(recipient.email)
    |> from(from_address)
    |> subject("Verify your notification email — #{channel.name}")
    |> text_body(
      "You were added as a CC recipient for monitoring alerts on the channel \"#{channel.name}\".\n\n" <>
        "Verify your email address: #{verification_url}\n\n" <>
        "This link expires in 48 hours. If you did not request this, you can ignore this email.\n"
    )
  end
end
