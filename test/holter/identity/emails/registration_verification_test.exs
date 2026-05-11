defmodule Holter.Identity.Emails.RegistrationVerificationTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Emails.RegistrationVerification
  alias Holter.Identity.Models.User

  defp build_email(overrides \\ []) do
    user = struct!(User, email: "alice@holter.test")

    opts =
      Keyword.merge(
        [url: "https://app.holter.test/identity/verify-email/abc123", from: "noreply@holter.dev"],
        overrides
      )

    RegistrationVerification.build_verification_email(user, %{
      url: opts[:url],
      from: opts[:from]
    })
  end

  describe "build_verification_email/2" do
    test "addresses the email to the user's email" do
      email = build_email()

      assert Enum.any?(email.to, fn {_, addr} -> addr == "alice@holter.test" end)
    end

    test "uses the configured from address" do
      email = build_email(from: "security@holter.test")

      assert {_name, "security@holter.test"} = email.from
    end

    test "subject identifies the verification action" do
      email = build_email()

      assert email.subject =~ "Verify"
    end

    test "embeds the verification URL verbatim in the body so users can click it" do
      url = "https://app.holter.test/identity/verify-email/clickable"

      email = build_email(url: url)

      assert email.text_body =~ url
    end

    test "warns recipients to ignore the message if they did not register" do
      email = build_email()

      assert email.text_body =~ "did not create"
    end

    test "frames the plain-text body with the shared Holter wordmark header" do
      email = build_email()

      assert String.starts_with?(email.text_body, "Holter")
    end

    test "ships an HTML body alongside the plain-text body" do
      email = build_email()

      assert is_binary(email.html_body) and email.html_body != ""
    end

    test "embeds the verification URL as a clickable anchor in the HTML body" do
      url = "https://app.holter.test/identity/verify-email/clickable-html"

      email = build_email(url: url)

      assert email.html_body =~ ~s(href="#{url}")
    end

    test "renders the welcome heading in the HTML body" do
      email = build_email()

      assert email.html_body =~ "Welcome to Holter"
    end
  end
end
