defmodule Holter.Delivery.Emails.EmailChannelVerification do
  @moduledoc false

  import Swoosh.Email

  def build_verification_email(channel, %{url: verification_url, from: from_address}) do
    new()
    |> to(channel.email_channel.address)
    |> from(from_address)
    |> subject("Confirm this address to receive monitoring alerts")
    |> text_body(
      "Someone configured a Holter monitoring service to send alerts to this address.\n\n" <>
        "If you confirm, you will receive notifications when an external system being monitored goes down or recovers. " <>
        "We do not disclose what is being monitored in this email so you can decide based on whether you expected the request, not the target.\n\n" <>
        "Confirm this address: #{verification_url}\n\n" <>
        "This link expires in 48 hours. If you did not expect this email, you can ignore it; no alerts will be sent.\n"
    )
  end
end
