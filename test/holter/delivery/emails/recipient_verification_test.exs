defmodule Holter.Delivery.Emails.RecipientVerificationTest do
  use Holter.DataCase, async: false

  alias Holter.Delivery.Emails.RecipientVerification
  alias Holter.Delivery.Models.{EmailChannel, EmailChannelRecipient}

  defp build_email(opts \\ []) do
    recipient = struct!(EmailChannelRecipient, email: "ops@example.com")
    channel = struct!(EmailChannel, name: "Ops Email")

    params =
      Keyword.merge(
        [
          url: "https://app.holter.test/email-channels/recipients/verify/abc123",
          from: "noreply@holter.dev"
        ],
        opts
      )

    RecipientVerification.build_verification_email(recipient, channel, %{
      url: params[:url],
      from: params[:from]
    })
  end

  describe "build_verification_email/3" do
    test "addresses the email to the recipient" do
      email = build_email()

      assert Enum.any?(email.to, fn {_, addr} -> addr == "ops@example.com" end)
    end

    test "uses the configured from address" do
      email = build_email(from: "security@holter.test")

      assert {_name, "security@holter.test"} = email.from
    end

    test "embeds the verification URL verbatim in the text body" do
      url = "https://app.holter.test/email-channels/recipients/verify/clickable-token"

      email = build_email(url: url)

      assert email.text_body =~ url
    end

    test "embeds the verification URL as a clickable anchor in the HTML body" do
      url = "https://app.holter.test/email-channels/recipients/verify/clickable-html"

      email = build_email(url: url)

      assert email.html_body =~ ~s(href="#{url}")
    end

    test "discloses neither the monitor URL nor the channel name to preserve recipient choice" do
      email = build_email()

      assert email.html_body =~ "do not disclose what is being monitored"
    end

    test "frames the plain-text body with the shared Holter wordmark header" do
      email = build_email()

      assert String.starts_with?(email.text_body, "Holter")
    end

    test "renders the subject in pt_BR when the gettext locale is pt_BR" do
      Gettext.put_locale(HolterWeb.Gettext, "pt_BR")
      on_exit(fn -> Gettext.put_locale(HolterWeb.Gettext, "en") end)

      email = build_email()

      assert email.subject == "Confirme este endereço para receber alertas de monitoramento"
    end

    test "renders the HTML heading in pt_BR when the gettext locale is pt_BR" do
      Gettext.put_locale(HolterWeb.Gettext, "pt_BR")
      on_exit(fn -> Gettext.put_locale(HolterWeb.Gettext, "en") end)

      email = build_email()

      assert email.html_body =~ "Confirme este endereço"
    end
  end
end
