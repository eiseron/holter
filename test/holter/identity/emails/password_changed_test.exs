defmodule Holter.Identity.Emails.PasswordChangedTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Emails.PasswordChanged
  alias Holter.Identity.User

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
  end
end
