defmodule Holter.Monitoring.SecurityScanner do
  @moduledoc """
  Logic for processing security-related checks like SSL expiration.
  """
  alias Holter.Monitoring

  def process_ssl(monitor, expiration_date) do
    now = DateTime.utc_now()
    days_until_expiry = DateTime.diff(expiration_date, now, :day)

    update_monitor_expiry(monitor, expiration_date)
    dispatch_incident_logic(monitor, days_until_expiry, now)
  end

  defp update_monitor_expiry(monitor, expiration_date) do
    Monitoring.update_monitor(monitor, %{ssl_expires_at: expiration_date})
  end

  defp dispatch_incident_logic(monitor, days, now) when days < 0 do
    upsert_incident(monitor, :ssl_expiry, now, "Certificate expired")
  end

  defp dispatch_incident_logic(monitor, days, now) when days < 7 do
    upsert_incident(monitor, :ssl_expiry, now, "Certificate expires in #{days} days (Critical)")
  end

  defp dispatch_incident_logic(monitor, days, now) when days < 15 do
    upsert_incident(monitor, :ssl_expiry, now, "Certificate expires in #{days} days (Warning)")
  end

  defp dispatch_incident_logic(monitor, _days, now) do
    resolve_ssl_incident(monitor, now)
  end

  def resolve_ssl_incident(monitor, now) do
    case Monitoring.get_open_incident(monitor.id, :ssl_expiry) do
      nil -> :ok
      incident -> Monitoring.resolve_incident(incident, now)
    end
  end

  defp upsert_incident(monitor, type, now, cause) do
    case Monitoring.get_open_incident(monitor.id, type) do
      nil -> create_ssl_incident(monitor, type, now, cause)
      incident -> update_ssl_incident(incident, cause)
    end
  end

  defp create_ssl_incident(monitor, type, now, cause) do
    Monitoring.create_incident(%{
      monitor_id: monitor.id,
      type: type,
      started_at: now,
      root_cause: cause
    })
  end

  defp update_ssl_incident(incident, cause) do
    if incident.root_cause != cause do
      Monitoring.update_incident(incident, %{root_cause: cause})
    end
  end
end
