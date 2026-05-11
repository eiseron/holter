defmodule Holter.Delivery.Emails.AlertTest do
  @moduledoc """
  HEEx template for the test-ping email sent when an operator clicks "Send
  test" on an email channel. Pure functions consumed by
  `Holter.Delivery.Engine.ChannelFormatter`; no IO, no Repo, no clock.
  """

  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Emails.{Components, Layout}

  def subject(%{channel: %{name: name}}) do
    gettext("Test notification from %{name}", name: name)
  end

  def text_lines(%{channel: %{name: name}, timestamp: timestamp}) do
    [
      gettext("This is a test notification from channel: %{name}", name: name),
      gettext("Timestamp: %{timestamp}", timestamp: timestamp)
    ]
  end

  attr :channel_name, :string, required: true
  attr :timestamp, :any, required: true
  attr :anti_phishing_code, :string, default: nil

  def html(assigns) do
    ~H"""
    <Layout.html
      title={subject(%{channel: %{name: @channel_name}})}
      preheader={dgettext("emails", "A test notification to verify channel delivery.")}
    >
      <h1 style="margin: 0 0 16px 0; font-size: 22px; line-height: 1.3; color: #fafafa;">
        {dgettext("emails", "Test notification")}
      </h1>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "This is a test notification from channel %{name}.",
          name: @channel_name
        )}
      </p>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "If you received this message, delivery to this address is working."
        )}
      </p>
      <Components.kv_table>
        <Components.kv_row label={dgettext("emails", "Channel")} value={@channel_name} />
        <Components.kv_row label={dgettext("emails", "Timestamp")} value={to_string(@timestamp)} />
      </Components.kv_table>
      <:footer>
        <Components.anti_phishing_footer code={@anti_phishing_code} />
      </:footer>
    </Layout.html>
    """
  end
end
