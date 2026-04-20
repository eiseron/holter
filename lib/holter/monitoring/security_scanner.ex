defmodule Holter.Monitoring.SecurityScanner do
  @moduledoc """
  Logic for processing security-related checks like SSL expiration.
  """

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  def process_ssl(monitor, expiration_date) do
    now = DateTime.utc_now()

    {:ok, updated_monitor} =
      Monitoring.update_monitor(monitor, %{ssl_expires_at: expiration_date})

    expiration_date
    |> DateTime.diff(now, :day)
    |> classify_ssl_expiry()
    |> dispatch_ssl_action(updated_monitor, now)

    Monitoring.recalculate_health_status(updated_monitor)
  end

  def handle_ssl_error(monitor, reason) do
    now = DateTime.utc_now()
    cause = gettext("SSL Error: %{reason}", reason: inspect(reason))
    open_or_update_ssl_incident(monitor, %{type: :ssl_expiry, now: now, cause: cause})
    Monitoring.recalculate_health_status(monitor)
  end

  def resolve_ssl_incident(monitor, now) do
    do_resolve_ssl_incident(monitor, now)
    Monitoring.recalculate_health_status(monitor)
  end

  defp classify_ssl_expiry(days) when days < 0, do: {:open, gettext("Certificate expired")}

  defp classify_ssl_expiry(days) when days < 7,
    do: {:open, gettext("Certificate expires in %{days} days (Critical)", days: days)}

  defp classify_ssl_expiry(days) when days < 15,
    do: {:open, gettext("Certificate expires in %{days} days (Warning)", days: days)}

  defp classify_ssl_expiry(_days), do: :resolve

  defp dispatch_ssl_action({:open, cause}, monitor, now),
    do: open_or_update_ssl_incident(monitor, %{type: :ssl_expiry, now: now, cause: cause})

  defp dispatch_ssl_action(:resolve, monitor, now),
    do: do_resolve_ssl_incident(monitor, now)

  defp do_resolve_ssl_incident(monitor, now) do
    case Monitoring.get_open_incident(monitor.id, :ssl_expiry) do
      nil -> :ok
      incident -> {:ok, _} = Monitoring.resolve_incident(incident, now)
    end
  end

  defp open_or_update_ssl_incident(monitor, params) do
    case Monitoring.get_open_incident(monitor.id, params.type) do
      nil -> create_ssl_incident(monitor, params)
      incident -> update_ssl_incident(incident, params.cause)
    end
  end

  defp create_ssl_incident(monitor, params) do
    Monitoring.create_incident(%{
      monitor_id: monitor.id,
      type: params.type,
      started_at: params.now,
      root_cause: params.cause,
      monitor_snapshot: Monitor.capture_snapshot(monitor)
    })
  end

  defp update_ssl_incident(incident, cause) do
    if incident.root_cause != cause do
      Monitoring.update_incident(incident, %{root_cause: cause})
    end
  end
end
