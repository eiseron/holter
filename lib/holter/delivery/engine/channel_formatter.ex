defmodule Holter.Delivery.Engine.ChannelFormatter do
  @moduledoc false

  alias Holter.Delivery.EmailChannel

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
      "\n\nVerification code: #{code}\n" <>
      "If you did not expect this email, do not trust messages claiming to be from Holter that omit this code.\n" <>
      "Do not forward this email to anyone you do not trust — the verification code above is a shared secret that lets the recipient impersonate Holter."
  end

  def append_anti_phishing_footer(body, _), do: body

  defp build_email_subject(%{event: "test_ping", channel: %{name: name}}) do
    "Test notification from #{name}"
  end

  defp build_email_subject(%{event: "monitor_down", monitor: %{url: url}}) do
    "Alert: #{url} is down"
  end

  defp build_email_subject(%{event: "monitor_up", monitor: %{url: url}}) do
    "Resolved: #{url} is back up"
  end

  defp build_email_subject(%{event: event, monitor: %{url: url}}) do
    "#{event} — #{url}"
  end

  defp build_email_body(%{event: "test_ping", channel: %{name: name}} = payload) do
    "This is a test notification from channel: #{name}\nTimestamp: #{payload.timestamp}"
  end

  defp build_email_body(payload) do
    monitor = payload.monitor
    incident = payload[:incident]

    lines = [
      "Event: #{payload.event}",
      "Monitor: #{monitor.url}",
      "Status: #{monitor.health_status}",
      "Timestamp: #{payload.timestamp}"
    ]

    lines =
      if incident do
        lines ++
          [
            "Incident type: #{incident.type}",
            "Started at: #{incident.started_at}",
            "Root cause: #{incident.root_cause || "unknown"}"
          ]
      else
        lines
      end

    Enum.join(lines, "\n")
  end
end
