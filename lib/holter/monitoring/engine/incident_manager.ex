defmodule Holter.Monitoring.Engine.IncidentManager do
  @moduledoc false

  alias Holter.Monitoring
  alias Holter.Monitoring.{Incidents, Monitors}

  def determine_incident_ops(%{check_status: :up}) do
    [{:resolve, :downtime}, {:resolve, :defacement}]
  end

  def determine_incident_ops(%{check_status: :down, defacement_in_body: true} = ctx) do
    [
      {:resolve, :defacement},
      {:open, :downtime, ctx.error_msg},
      {:open, :defacement, ctx.error_msg}
    ]
  end

  def determine_incident_ops(%{check_status: :down} = ctx) do
    [{:resolve, :defacement}, {:open, :downtime, ctx.error_msg}]
  end

  def determine_incident_ops(%{check_status: :compromised, positive_ok: false} = ctx) do
    [{:open, :downtime, ctx.downtime_error_msg}, {:open, :defacement, ctx.defacement_error_msg}]
  end

  def determine_incident_ops(%{check_status: :compromised} = ctx) do
    [{:resolve, :downtime}, {:open, :defacement, ctx.error_msg}]
  end

  def apply_incident_ops(monitor, ops, ctx),
    do: Enum.each(ops, &apply_incident_op(monitor, &1, ctx))

  def apply_incident_op(monitor, {:resolve, type}, ctx),
    do: resolve_if_open(monitor, type, ctx.now)

  def apply_incident_op(monitor, {:open, type, error_msg}, ctx),
    do: open_if_missing(monitor, type, %{ctx | error_msg: error_msg})

  def resolve_if_open(monitor, type, now) do
    case Monitoring.get_open_incident(monitor.id, type) do
      nil -> :ok
      incident -> Monitoring.resolve_incident(incident, now)
    end
  end

  def open_if_missing(monitor, type, metadata) do
    case Monitoring.get_open_incident(monitor.id, type) do
      nil -> create_incident_idempotent(monitor, type, metadata)
      _ -> :ok
    end
  end

  def create_incident_idempotent(monitor, type, metadata) do
    result =
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: type,
        started_at: metadata.now,
        root_cause: metadata.error_msg,
        monitor_snapshot: metadata.snapshot
      })

    if Monitoring.open_incident_already_exists?(result), do: :ok, else: result
  end

  def pick_active_incident([]), do: {nil, :unknown}

  def pick_active_incident(incidents) do
    incident =
      Enum.max_by(incidents, fn i ->
        Monitors.status_severity(Incidents.incident_to_health(i))
      end)

    {incident.id, Incidents.incident_to_health(incident)}
  end
end
