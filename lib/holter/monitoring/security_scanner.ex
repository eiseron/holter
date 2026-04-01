defmodule Holter.Monitoring.SecurityScanner do
  @moduledoc """
  Logic for processing security-related checks like SSL expiration.
  """
  alias Holter.Monitoring

  def process_ssl(monitor, expiration_date) do
    now = DateTime.utc_now()
    days_until_expiry = DateTime.diff(expiration_date, now, :day)

    update_monitor_expiry(monitor, expiration_date)
    handle_expiry_incidents(monitor, days_until_expiry, now)
  end

  defp update_monitor_expiry(monitor, expiration_date) do
    Monitoring.update_monitor(monitor, %{ssl_expires_at: expiration_date})
  end

  defp handle_expiry_incidents(monitor, days, now) when days < 0 do
    # Already expired - should be handled as DOWN by engine if not ignored
    # but we can also open an incident specifically for expiry
    ensure_incident(monitor, :ssl_expiry, now, "Certificate expired")
  end

  defp handle_expiry_incidents(monitor, days, now) when days < 7 do
    ensure_incident(monitor, :ssl_expiry, now, "Certificate expires in #{days} days (Critical)")
  end

  defp handle_expiry_incidents(monitor, days, now) when days < 15 do
    ensure_incident(monitor, :ssl_expiry, now, "Certificate expires in #{days} days (Warning)")
  end

  defp handle_expiry_incidents(monitor, _days, now) do
    resolve_incident_if_exists(monitor, now)
  end

  defp ensure_incident(monitor, type, now, cause) do
    case Monitoring.get_open_incident(monitor.id) do
      nil ->
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: type,
          started_at: now,
          root_cause: cause
        })

      incident ->
        # Update cause if it changed significantly
        if incident.root_cause != cause do
          Monitoring.update_incident(incident, %{root_cause: cause})
        end
    end
  end

  defp resolve_incident_if_exists(monitor, now) do
    case Monitoring.get_open_incident(monitor.id) do
      %{type: :ssl_expiry} = incident ->
        Monitoring.resolve_incident(incident, now)

      _ ->
        :ok
    end
  end
end
