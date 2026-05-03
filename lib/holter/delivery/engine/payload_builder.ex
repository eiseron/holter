defmodule Holter.Delivery.Engine.PayloadBuilder do
  @moduledoc false

  @version "1.0"

  def build_incident_payload(monitor, incident, %{event: event, now: now})
      when event in [:down, :up] do
    %{
      version: @version,
      event: build_event_name(event, incident.type),
      timestamp: DateTime.to_iso8601(now),
      monitor: build_monitor_data(monitor),
      incident: build_incident_data(incident)
    }
  end

  def build_test_payload(channel, type, now) when type in [:webhook, :email] do
    %{
      version: @version,
      event: "test_ping",
      timestamp: DateTime.to_iso8601(now),
      channel: %{id: channel.id, name: channel.name, type: type}
    }
  end

  defp build_event_name(:down, _type), do: "monitor_down"
  defp build_event_name(:up, _type), do: "monitor_up"

  defp build_monitor_data(monitor) do
    %{
      id: monitor.id,
      url: monitor.url,
      health_status: monitor.health_status
    }
  end

  defp build_incident_data(incident) do
    %{
      id: incident.id,
      type: incident.type,
      started_at: DateTime.to_iso8601(incident.started_at),
      resolved_at: build_resolved_at(incident.resolved_at),
      duration_seconds: incident.duration_seconds,
      root_cause: incident.root_cause
    }
  end

  defp build_resolved_at(nil), do: nil
  defp build_resolved_at(dt), do: DateTime.to_iso8601(dt)
end
