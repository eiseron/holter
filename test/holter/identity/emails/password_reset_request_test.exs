defmodule Holter.Identity.Emails.PasswordResetRequestTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Emails.PasswordResetRequest
  alias Holter.Identity.Models.User

  defp build_email(overrides \\ []) do
    user = struct!(User, email: "alice@holter.test")

    opts =
      Keyword.merge(
        [
          url: "https://app.holter.test/identity/reset-password/abc123",
          from: "noreply@holter.dev"
        ],
        overrides
      )

    PasswordResetRequest.build_reset_email(user, %{url: opts[:url], from: opts[:from]})
  end

  describe "build_reset_email/2" do
    test "addresses the email to the user's email" do
      email = build_email()

      assert Enum.any?(email.to, fn {_, addr} -> addr == "alice@holter.test" end)
    end

    test "uses the configured from address" do
      email = build_email(from: "security@holter.test")

      assert {_name, "security@holter.test"} = email.from
    end

    test "subject identifies the password reset action" do
      email = build_email()

      assert email.subject =~ "password"
    end

    test "embeds the reset URL verbatim so the user can click it" do
      url = "https://app.holter.test/identity/reset-password/clickable-token"

      email = build_email(url: url)

      assert email.text_body =~ url
    end

    test "tells the recipient to ignore the message if they did not request a reset" do
      email = build_email()

      assert email.text_body =~ "ignore"
    end

    test "states the link expires in 15 minutes so users do not stash it" do
      email = build_email()

      assert email.text_body =~ "15"
    end
  end
end
