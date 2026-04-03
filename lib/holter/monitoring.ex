defmodule Holter.Monitoring do
  @moduledoc """
  The Monitoring context.
  """

  alias Holter.Monitoring.{Monitors, Logs, Incidents, Metrics}

  defdelegate list_monitors, to: Monitors
  defdelegate get_monitor!(id), to: Monitors
  defdelegate create_monitor(attrs), to: Monitors
  defdelegate update_monitor(monitor, attrs), to: Monitors
  defdelegate delete_monitor(monitor), to: Monitors
  defdelegate change_monitor(monitor, attrs \\ %{}), to: Monitors
  defdelegate recalculate_health_status(monitor), to: Monitors
  defdelegate list_monitors_for_dispatch, to: Monitors

  defdelegate list_monitor_logs(monitor_id), to: Logs
  defdelegate get_monitor_log!(id), to: Logs
  defdelegate create_monitor_log(attrs \\ %{}), to: Logs

  defdelegate list_incidents(monitor_id), to: Incidents
  defdelegate get_open_incident(monitor_id), to: Incidents
  defdelegate get_open_incident(monitor_id, type), to: Incidents
  defdelegate list_open_incidents(monitor_id), to: Incidents
  defdelegate create_incident(attrs \\ %{}), to: Incidents
  defdelegate update_incident(incident, attrs), to: Incidents
  defdelegate resolve_incident(incident, resolved_at), to: Incidents

  defdelegate list_daily_metrics(monitor_id), to: Metrics
  defdelegate get_daily_metric(monitor_id, date), to: Metrics
  defdelegate upsert_daily_metric(attrs), to: Metrics
end
