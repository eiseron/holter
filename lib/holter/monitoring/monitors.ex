defmodule Holter.Monitoring.Monitors do
  @moduledoc false

  import Ecto.Query
  alias Holter.Repo
  alias Holter.Monitoring.Monitor

  def list_monitors do
    Repo.all(Monitor)
  end

  def get_monitor!(id), do: Repo.get!(Monitor, id)

  def create_monitor(attrs \\ %{}) do
    %Monitor{}
    |> Monitor.changeset(attrs)
    |> Repo.insert()
  end

  def update_monitor(%Monitor{} = monitor, attrs) do
    monitor
    |> Monitor.changeset(attrs)
    |> Repo.update()
  end

  def delete_monitor(%Monitor{} = monitor) do
    Repo.delete(monitor)
  end

  def change_monitor(%Monitor{} = monitor, attrs \\ %{}) do
    Monitor.changeset(monitor, attrs)
  end

  def recalculate_health_status(%Monitor{} = monitor) do
    new_status =
      monitor.id
      |> Holter.Monitoring.Incidents.list_open_incidents()
      |> determine_overall_status()

    if monitor.health_status != new_status do
      update_monitor(monitor, %{health_status: new_status})
    else
      {:ok, monitor}
    end
  end

  defp determine_overall_status([]), do: :up

  defp determine_overall_status(incidents) do
    incidents
    |> Enum.map(&incident_to_health/1)
    |> Enum.max_by(&status_severity/1, fn -> :up end)
  end

  defp incident_to_health(%{type: :downtime}), do: :down
  defp incident_to_health(%{type: :defacement}), do: :compromised

  defp incident_to_health(%{type: :ssl_expiry, root_cause: rc}) do
    cond do
      is_nil(rc) -> :degraded
      String.contains?(rc, "Critical") -> :compromised
      String.contains?(rc, "expired") -> :compromised
      String.contains?(rc, "SSL Error") -> :compromised
      true -> :degraded
    end
  end

  defp incident_to_health(_), do: :unknown

  defp status_severity(:down), do: 4
  defp status_severity(:compromised), do: 3
  defp status_severity(:degraded), do: 2
  defp status_severity(:up), do: 1
  defp status_severity(_), do: 0

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
