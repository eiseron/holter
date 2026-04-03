defmodule Holter.Monitoring.Monitors do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.Incidents
  alias Holter.Monitoring.Monitor
  alias Holter.Repo

  def list_monitors do
    Repo.all(Monitor)
  end

  def get_monitor!(id), do: Repo.get!(Monitor, id)

  def create_monitor(attrs \\ %{}) do
    case %Monitor{}
         |> Monitor.changeset(attrs)
         |> Repo.insert() do
      {:ok, monitor} ->
        broadcast({:ok, monitor}, :monitor_created)
        {:ok, monitor}

      error ->
        error
    end
  end

  def update_monitor(%Monitor{} = monitor, attrs) do
    case monitor
         |> Monitor.changeset(attrs)
         |> Repo.update() do
      {:ok, updated} ->
        broadcast({:ok, updated}, :monitor_updated)
        {:ok, updated}

      error ->
        error
    end
  end

  defp broadcast({:ok, monitor}, event) do
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitor:#{monitor.id}", {event, monitor})
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitors", {event, monitor})
    {:ok, monitor}
  end

  defp broadcast(error, _), do: error

  def delete_monitor(%Monitor{} = monitor) do
    Repo.delete(monitor)
  end

  def change_monitor(%Monitor{} = monitor, attrs \\ %{}) do
    Monitor.changeset(monitor, attrs)
  end

  @doc """
  Recalculates overall health status based on all open incidents.
  Returns {:ok, updated_monitor}.
  """
  def recalculate_health_status(%Monitor{} = monitor) do
    open_incidents = Incidents.list_open_incidents(monitor.id)
    new_status = determine_overall_status(open_incidents)

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
