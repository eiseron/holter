defmodule Holter.Monitoring.DomainScanner do
  @moduledoc """
  Logic for processing domain registration / WHOIS-RDAP checks.

  Mirrors the SSL flow in `SecurityScanner` but operates on domain
  expirations instead of certificate expirations. Lookup errors do NOT
  open incidents — RDAP failures are usually transient registrar-side
  issues unrelated to the monitored site.
  """

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Monitoring
  alias Holter.Monitoring.{Incidents, Monitor}

  def process_domain(monitor, expiration_date) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, updated_monitor} =
      Monitoring.update_monitor(monitor, %{
        domain_expires_at: expiration_date,
        last_domain_check_at: now
      })

    expiration_date
    |> DateTime.diff(now, :day)
    |> classify_domain_expiry()
    |> dispatch_domain_action(updated_monitor, now)

    Monitoring.recalculate_health_status(updated_monitor)
  end

  def handle_domain_error(monitor, _reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, _} = Monitoring.update_monitor(monitor, %{last_domain_check_at: now})
    :ok
  end

  def resolve_domain_incident(monitor, now) do
    do_resolve_domain_incident(monitor, now)
    Monitoring.recalculate_health_status(monitor)
  end

  defp classify_domain_expiry(days) when days < 0, do: {:open, gettext("Domain expired")}

  defp classify_domain_expiry(days) when days < 7,
    do: {:open, gettext("Domain expires in %{days} days (Critical)", days: days)}

  defp classify_domain_expiry(days) when days < 30,
    do: {:open, gettext("Domain expires in %{days} days (Warning)", days: days)}

  defp classify_domain_expiry(_days), do: :resolve

  defp dispatch_domain_action({:open, cause}, monitor, now),
    do: open_or_update_domain_incident(monitor, %{type: :domain_expiry, now: now, cause: cause})

  defp dispatch_domain_action(:resolve, monitor, now),
    do: do_resolve_domain_incident(monitor, now)

  defp do_resolve_domain_incident(monitor, now) do
    case Monitoring.get_open_incident(monitor.id, :domain_expiry) do
      nil ->
        :ok

      incident ->
        {:ok, _} = Monitoring.resolve_incident(incident, now)

        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          checked_at: now,
          monitor_snapshot: Monitor.capture_snapshot(monitor)
        })
    end
  end

  defp open_or_update_domain_incident(monitor, params) do
    case Monitoring.get_open_incident(monitor.id, params.type) do
      nil -> create_domain_incident(monitor, params)
      incident -> update_domain_incident(monitor, incident, params)
    end
  end

  defp create_domain_incident(monitor, params) do
    case Monitoring.create_incident(%{
           monitor_id: monitor.id,
           type: params.type,
           started_at: params.now,
           root_cause: params.cause,
           monitor_snapshot: Monitor.capture_snapshot(monitor)
         }) do
      {:ok, incident} ->
        create_domain_log(monitor, incident, params.now)
        {:ok, incident}

      error ->
        error
    end
  end

  defp update_domain_incident(monitor, incident, params) do
    if incident.root_cause != params.cause do
      {:ok, updated} = Monitoring.update_incident(incident, %{root_cause: params.cause})
      create_domain_log(monitor, updated, params.now)
      {:ok, updated}
    end
  end

  defp create_domain_log(monitor, incident, now) do
    Monitoring.create_monitor_log(%{
      monitor_id: monitor.id,
      incident_id: incident.id,
      status: Incidents.incident_to_health(incident),
      checked_at: now,
      error_message: incident.root_cause,
      monitor_snapshot: Monitor.capture_snapshot(monitor)
    })
  end
end
