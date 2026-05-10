defmodule Holter.Delivery.Engine.ChannelFormatter do
  @moduledoc false

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Delivery.Models.EmailChannel

  def format_payload(payload, :webhook) do
    {:ok, json} = Jason.encode(payload)
    {json, [{"content-type", "application/json"}]}
  end

  def format_payload(payload, :email) do
    subject = build_email_subject(payload)
    body = build_email_body(payload)
    {subject, body}
  end

  @doc """
  Appends the channel's anti-phishing footer to an email body. Recipients
  use the printed code as a sanity check that the message is genuinely
  from Holter and not a spoofed phishing attempt.
  """
  def append_anti_phishing_footer(body, %EmailChannel{anti_phishing_code: code})
      when is_binary(code) do
    body <>
      "\n\n" <>
      gettext("Verification code: %{code}", code: code) <>
      "\n" <>
      gettext(
        "If you did not expect this email, do not trust messages claiming to be from Holter that omit this code."
      ) <>
      "\n" <>
      gettext(
        "Do not forward this email to anyone you do not trust — the verification code above is a shared secret that lets the recipient impersonate Holter."
      )
  end

  def append_anti_phishing_footer(body, _), do: body

  defp build_email_subject(%{event: "test_ping", channel: %{name: name}}) do
    gettext("Test notification from %{name}", name: name)
  end

  defp build_email_subject(%{event: "monitor_down", monitor: %{url: url}}) do
    gettext("Alert: %{url} is down", url: url)
  end

  defp build_email_subject(%{event: "monitor_up", monitor: %{url: url}}) do
    gettext("Resolved: %{url} is back up", url: url)
  end

  defp build_email_subject(%{event: event, monitor: %{url: url}}) do
    "#{event} — #{url}"
  end

  defp build_email_body(%{event: "test_ping", channel: %{name: name}} = payload) do
    gettext("This is a test notification from channel: %{name}", name: name) <>
      "\n" <>
      gettext("Timestamp: %{timestamp}", timestamp: payload.timestamp)
  end

  defp build_email_body(payload) do
    monitor = payload.monitor
    incident = payload[:incident]

    lines = [
      gettext("Event: %{event}", event: payload.event),
      gettext("Monitor: %{url}", url: monitor.url),
      gettext("Status: %{status}", status: monitor.health_status),
      gettext("Timestamp: %{timestamp}", timestamp: payload.timestamp)
    ]

    lines =
      if incident do
        lines ++
          [
            gettext("Incident type: %{type}", type: incident.type),
            gettext("Started at: %{started_at}", started_at: incident.started_at),
            gettext("Root cause: %{cause}", cause: incident.root_cause || gettext("unknown"))
          ]
      else
        lines
      end

    Enum.join(lines, "\n")
  end
end
