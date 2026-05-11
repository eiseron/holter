defmodule Holter.Emails.Previews do
  @moduledoc """
  Catalogue of every Holter notification email rendered against fixture
  data, used exclusively by the dev preview LiveView at `/dev/emails`.

  Each preview drives the real `build_*` function with struct literals so
  the dev surface exercises the same code path that production uses; no
  parallel render exists. Builds run inside the requested gettext locale
  and the locale is restored before this function returns so callers
  never observe a side effect on the surrounding process.
  """

  alias Holter.Delivery.Emails.RecipientVerification
  alias Holter.Delivery.Engine.ChannelFormatter
  alias Holter.Delivery.Models.{EmailChannel, EmailChannelRecipient}
  alias Holter.Identity.Emails.{PasswordChanged, PasswordResetRequest, RegistrationVerification}
  alias Holter.Identity.Models.User
  alias Holter.Monitoring.Models.{Incident, Monitor}

  @locales ["en", "pt_BR"]

  def locales, do: @locales

  def list do
    [
      %{
        key: :registration_verification,
        label: "Registration verification",
        group: :identity,
        variants: [%{key: :default, label: "Default"}]
      },
      %{
        key: :password_reset_request,
        label: "Password reset request",
        group: :identity,
        variants: [%{key: :default, label: "Default"}]
      },
      %{
        key: :password_changed,
        label: "Password changed",
        group: :identity,
        variants: [%{key: :default, label: "Default"}]
      },
      %{
        key: :recipient_verification,
        label: "Recipient verification (channel opt-in)",
        group: :delivery,
        variants: [%{key: :default, label: "Default"}]
      },
      %{
        key: :alert_down,
        label: "Alert: monitor down",
        group: :delivery,
        variants: [
          %{key: :with_root_cause, label: "With root cause"},
          %{key: :without_root_cause, label: "Without root cause"}
        ]
      },
      %{
        key: :alert_up,
        label: "Alert: monitor recovered",
        group: :delivery,
        variants: [%{key: :default, label: "Default"}]
      },
      %{
        key: :alert_test,
        label: "Test ping",
        group: :delivery,
        variants: [%{key: :default, label: "Default"}]
      }
    ]
  end

  def find(preview_key, variant_key) do
    Enum.find(list(), fn p ->
      p.key == preview_key and Enum.any?(p.variants, &(&1.key == variant_key))
    end)
  end

  def build(preview_key, variant_key, locale)
      when locale in @locales do
    previous_locale = Gettext.get_locale(HolterWeb.Gettext)
    Gettext.put_locale(HolterWeb.Gettext, locale)

    try do
      build_preview(preview_key, variant_key)
    after
      Gettext.put_locale(HolterWeb.Gettext, previous_locale)
    end
  end

  defp build_preview(:registration_verification, :default) do
    RegistrationVerification.build_verification_email(sample_user(), %{
      url: "https://app.holter.test/identity/verify-email/sample-token",
      from: "noreply@holter.dev"
    })
  end

  defp build_preview(:password_reset_request, :default) do
    PasswordResetRequest.build_reset_email(sample_user(), %{
      url: "https://app.holter.test/identity/reset-password/sample-token",
      from: "noreply@holter.dev"
    })
  end

  defp build_preview(:password_changed, :default) do
    PasswordChanged.build_alert_email(sample_user(), %{from: "noreply@holter.dev"})
  end

  defp build_preview(:recipient_verification, :default) do
    RecipientVerification.build_verification_email(sample_recipient(), sample_channel(), %{
      url: "https://app.holter.test/email-channels/recipients/verify/sample-token",
      from: "noreply@holter.dev"
    })
  end

  defp build_preview(:alert_down, :with_root_cause) do
    build_alert_email(down_payload(root_cause: "HTTP 500 from upstream"))
  end

  defp build_preview(:alert_down, :without_root_cause) do
    build_alert_email(down_payload(root_cause: nil))
  end

  defp build_preview(:alert_up, :default) do
    build_alert_email(%{down_payload(root_cause: "HTTP 500 from upstream") | event: "monitor_up"})
  end

  defp build_preview(:alert_test, :default) do
    build_alert_email(test_payload())
  end

  defp build_alert_email(payload) do
    channel = sample_channel()
    formatted = ChannelFormatter.format_email(payload, channel)

    Swoosh.Email.new()
    |> Swoosh.Email.from({"Holter", "noreply@alerts.holter.dev"})
    |> Swoosh.Email.to({"Recipient", "ops@example.com"})
    |> Swoosh.Email.subject(formatted.subject)
    |> Swoosh.Email.text_body(formatted.text)
    |> Swoosh.Email.html_body(formatted.html)
  end

  defp sample_user, do: struct!(User, email: "alice@holter.test")

  defp sample_recipient,
    do: struct!(EmailChannelRecipient, email: "ops@example.com")

  defp sample_channel do
    struct!(EmailChannel,
      id: "ch-sample",
      workspace_id: "ws-sample",
      name: "Ops Email",
      anti_phishing_code: "ABCD-EFGH"
    )
  end

  defp down_payload(opts) do
    %{
      version: "1.0",
      event: "monitor_down",
      timestamp: "2026-05-11T10:00:00Z",
      monitor:
        struct!(Monitor, id: "mon-sample", url: "https://example.com", health_status: :down),
      incident:
        struct!(Incident,
          id: "inc-sample",
          type: :downtime,
          started_at: ~U[2026-05-11 09:55:12Z],
          resolved_at: nil,
          root_cause: Keyword.get(opts, :root_cause)
        )
    }
  end

  defp test_payload do
    %{
      version: "1.0",
      event: "test_ping",
      timestamp: "2026-05-11T10:00:00Z",
      channel: %{id: "ch-sample", name: "Ops Email"}
    }
  end
end
