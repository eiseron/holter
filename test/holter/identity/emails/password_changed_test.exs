defmodule Holter.Identity.Emails.PasswordChangedTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Emails.PasswordChanged
  alias Holter.Identity.Models.User

  defp build_email(overrides \\ []) do
    user = struct!(User, email: "alice@holter.test")

    opts = Keyword.merge([from: "noreply@holter.dev"], overrides)

    PasswordChanged.build_alert_email(user, %{from: opts[:from]})
  end

  describe "build_alert_email/2" do
    test "addresses the alert to the user's email" do
      email = build_email()

      assert Enum.any?(email.to, fn {_, addr} -> addr == "alice@holter.test" end)
    end

    test "uses the configured from address" do
      email = build_email(from: "security@holter.test")

      assert {_name, "security@holter.test"} = email.from
    end

    test "subject identifies the password-change alert" do
      email = build_email()

      assert email.subject == "Your password has been changed"
    end

    test "body invites the user to act if they did not perform the change" do
      email = build_email()

      assert email.text_body =~ "did not perform"
    end

    test "frames the plain-text body with the shared Holter wordmark header" do
      email = build_email()

      assert String.starts_with?(email.text_body, "Holter")
    end

    test "ships an HTML body alongside the plain-text body" do
      email = build_email()

      assert is_binary(email.html_body) and email.html_body != ""
    end

    test "states in the HTML body that all other sessions were revoked" do
      email = build_email()

      assert email.html_body =~ "revoked"
    end

    test "invites the user to contact support in the HTML body if the change was not theirs" do
      email = build_email()

      assert email.html_body =~ "contact support"
    end
  end
end
