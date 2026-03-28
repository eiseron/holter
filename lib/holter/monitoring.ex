defmodule Holter.Monitoring do
  @moduledoc """
  The Monitoring context.
  """

  import Ecto.Query, warn: false
  alias Holter.Repo

  alias Holter.Monitoring.Monitor

  @doc """
  Returns the list of monitors.
  """
  def list_monitors do
    Repo.all(Monitor)
  end

  @doc """
  Gets a single monitor.
  """
  def get_monitor!(id), do: Repo.get!(Monitor, id)

  @doc """
  Creates a monitor.
  """
  def create_monitor(attrs \\ %{}) do
    %Monitor{}
    |> Monitor.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a monitor.
  """
  def update_monitor(%Monitor{} = monitor, attrs) do
    monitor
    |> Monitor.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a monitor.
  """
  def delete_monitor(%Monitor{} = monitor) do
    Repo.delete(monitor)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking monitor changes.
  """
  def change_monitor(%Monitor{} = monitor, attrs \\ %{}) do
    Monitor.changeset(monitor, attrs)
  end

  # Monitor Logs

  alias Holter.Monitoring.MonitorLog

  def list_monitor_logs(monitor_id) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> order_by([l], desc: l.checked_at)
    |> Repo.all()
  end

  def create_monitor_log(attrs \\ %{}) do
    %MonitorLog{}
    |> MonitorLog.changeset(attrs)
    |> Repo.insert()
  end

  # Incidents

  alias Holter.Monitoring.Incident

  def list_incidents(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> order_by([i], desc: i.started_at)
    |> Repo.all()
  end

  def get_open_incident(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id and is_nil(i.resolved_at))
    |> Repo.one()
  end

  def create_incident(attrs \\ %{}) do
    %Incident{}
    |> Incident.changeset(attrs)
    |> Repo.insert()
  end

  def resolve_incident(%Incident{} = incident, resolved_at) do
    duration = DateTime.diff(resolved_at, incident.started_at)

    incident
    |> Incident.changeset(%{resolved_at: resolved_at, duration_seconds: duration})
    |> Repo.update()
  end

  # Engine Queries

  def list_monitors_for_dispatch do
    now = DateTime.utc_now()

    Monitor
    |> where([m], m.logical_state == :active)
    |> where(
      [m],
      is_nil(m.last_checked_at) or
        fragment(
          "? + (? * interval '1 second') <= ?",
          m.last_checked_at,
          m.interval_seconds,
          ^now
        )
    )
    |> Repo.all()
  end
end
