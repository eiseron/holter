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
