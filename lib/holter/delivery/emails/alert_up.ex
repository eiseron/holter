defmodule Holter.Delivery.Emails.AlertUp do
  @moduledoc """
  HEEx template for the email sent when a monitor recovers to a healthy
  state. Exposes pure functions consumed by
  `Holter.Delivery.Engine.ChannelFormatter`; no IO, no Repo, no clock.
  """

  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Delivery.Emails.AlertDown
  alias Holter.Emails.{Components, Layout}

  def subject(%{monitor: %{url: url}}) do
    gettext("Resolved: %{url} is back up", url: url)
  end

  defdelegate text_lines(payload), to: AlertDown

  attr :monitor, :map, required: true
  attr :incident, :map, default: nil
  attr :timestamp, :any, required: true
  attr :event, :string, required: true
  attr :anti_phishing_code, :string, default: nil

  def html(assigns) do
    ~H"""
    <Layout.html
      title={subject(%{monitor: @monitor})}
      preheader={dgettext("emails", "%{url} is reachable again.", url: @monitor.url)}
    >
      <h1 style="margin: 0 0 16px 0; font-size: 22px; line-height: 1.3; color: #37b9ff;">
        {dgettext("emails", "Monitor recovered")}
      </h1>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "%{url} is responding successfully again. Holter will keep watching it.",
          url: @monitor.url
        )}
      </p>
      <Components.kv_table>
        <Components.kv_row label={dgettext("emails", "Event")} value={@event} />
        <Components.kv_row label={dgettext("emails", "Monitor")} value={@monitor.url} />
        <Components.kv_row
          label={dgettext("emails", "Status")}
          value={to_string(@monitor.health_status)}
        />
        <Components.kv_row label={dgettext("emails", "Timestamp")} value={to_string(@timestamp)} />
        <Components.kv_row
          :if={@incident}
          label={dgettext("emails", "Incident type")}
          value={to_string(@incident.type)}
        />
        <Components.kv_row
          :if={@incident}
          label={dgettext("emails", "Started at")}
          value={to_string(@incident.started_at)}
        />
      </Components.kv_table>
      <:footer>
        <Components.anti_phishing_footer code={@anti_phishing_code} />
      </:footer>
    </Layout.html>
    """
  end
end
