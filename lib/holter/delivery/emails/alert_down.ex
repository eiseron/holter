defmodule Holter.Delivery.Emails.AlertDown do
  @moduledoc """
  HEEx template for the email sent when a monitor transitions to a down
  state. Exposes pure functions consumed by
  `Holter.Delivery.Engine.ChannelFormatter`; no IO, no Repo, no clock.
  """

  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Emails.{Components, Layout}

  def subject(%{monitor: %{url: url}}) do
    gettext("Alert: %{url} is down", url: url)
  end

  def text_lines(%{monitor: monitor, timestamp: timestamp} = payload) do
    incident = Map.get(payload, :incident)

    base = [
      gettext("Event: %{event}", event: payload.event),
      gettext("Monitor: %{url}", url: monitor.url),
      gettext("Status: %{status}", status: monitor.health_status),
      gettext("Timestamp: %{timestamp}", timestamp: timestamp)
    ]

    if incident, do: base ++ incident_lines(incident), else: base
  end

  attr :monitor, :map, required: true
  attr :incident, :map, default: nil
  attr :timestamp, :any, required: true
  attr :event, :string, required: true
  attr :anti_phishing_code, :string, default: nil

  def html(assigns) do
    ~H"""
    <Layout.html
      title={subject(%{monitor: @monitor})}
      preheader={dgettext("emails", "Holter detected that %{url} is unreachable.", url: @monitor.url)}
    >
      <h1 style="margin: 0 0 16px 0; font-size: 22px; line-height: 1.3; color: #ff3366;">
        {dgettext("emails", "Monitor down")}
      </h1>
      <p style="margin: 0 0 16px 0; font-size: 15px; line-height: 1.55; color: #fafafa;">
        {dgettext(
          "emails",
          "Holter detected that %{url} is currently unreachable or returning errors.",
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
        <Components.kv_row
          :if={@incident}
          label={dgettext("emails", "Root cause")}
          value={to_string(@incident.root_cause || dgettext("emails", "unknown"))}
        />
      </Components.kv_table>
      <:footer>
        <Components.anti_phishing_footer code={@anti_phishing_code} />
      </:footer>
    </Layout.html>
    """
  end

  defp incident_lines(incident) do
    [
      gettext("Incident type: %{type}", type: incident.type),
      gettext("Started at: %{started_at}", started_at: incident.started_at),
      gettext("Root cause: %{cause}", cause: incident.root_cause || gettext("unknown"))
    ]
  end
end
