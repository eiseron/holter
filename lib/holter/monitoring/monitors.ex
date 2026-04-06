defmodule Holter.Monitoring.Monitors do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.{Incidents, Monitor}
  alias Holter.Repo

  def list_monitors do
    Repo.all(Monitor)
  end

  def list_monitors_by_workspace(workspace_id) do
    Monitor
    |> where([m], m.workspace_id == ^workspace_id)
    |> tactical_ranking()
    |> Repo.all()
  end

  def list_monitors_with_sparklines(workspace_id, log_limit \\ 30) do
    monitors =
      Monitor
      |> where([m], m.workspace_id == ^workspace_id)
      |> tactical_ranking()
      |> Repo.all()

    monitor_ids = Enum.map(monitors, & &1.id)

    logs_by_monitor =
      Holter.Monitoring.MonitorLog
      |> where([l], l.monitor_id in ^monitor_ids)
      |> order_by([l], asc: l.monitor_id, desc: l.checked_at)
      |> Repo.all()
      |> Enum.group_by(& &1.monitor_id)
      |> Map.new(fn {id, logs} -> {id, Enum.take(logs, log_limit)} end)

    Enum.map(monitors, fn monitor ->
      %{monitor | logs: Map.get(logs_by_monitor, monitor.id, [])}
    end)
  end

  def get_monitor!(id), do: Repo.get!(Monitor, id)

  def get_monitor(id) do
    case Repo.get(Monitor, id) do
      nil -> {:error, :not_found}
      monitor -> {:ok, monitor}
    end
  end

  @max_page_size 100
  @default_page_size 25

  def list_monitors_filtered(params) do
    workspace_id = Map.fetch!(params, :workspace_id)
    page = Map.get(params, :page, 1) |> max(1)
    page_size = Map.get(params, :page_size, @default_page_size) |> min(@max_page_size) |> max(1)

    base_query =
      Monitor
      |> where([m], m.workspace_id == ^workspace_id)

    filtered_query =
      base_query
      |> maybe_filter_by(:logical_state, params)
      |> maybe_filter_by(:health_status, params)

    total = Repo.aggregate(filtered_query, :count, :id)

    monitors =
      filtered_query
      |> tactical_ranking()
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    %{data: monitors, meta: %{page: page, page_size: page_size, total: total}}
  end

  defp maybe_filter_by(query, :logical_state, %{logical_state: state}) when not is_nil(state) do
    where(query, [m], m.logical_state == ^state)
  end

  defp maybe_filter_by(query, :health_status, %{health_status: status}) when not is_nil(status) do
    where(query, [m], m.health_status == ^status)
  end

  defp maybe_filter_by(query, _, _), do: query

  defp tactical_ranking(query) do
    query
    |> order_by([m],
      desc:
        fragment("""
        CASE
          WHEN health_status = 'down' THEN 4
          WHEN health_status = 'compromised' THEN 3
          WHEN health_status = 'degraded' THEN 2
          WHEN health_status = 'up' THEN 1
          ELSE 0
        END
        """),
      desc: m.inserted_at
    )
  end

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

  def mark_manual_check_triggered(%Monitor{} = monitor) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update_monitor(monitor, %{last_manual_check_at: now})
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

  def recalculate_health_status(%Monitor{id: id}) do
    monitor = get_monitor!(id)
    log_status = status_from_latest_log(monitor.id)
    open_incidents = Incidents.list_open_incidents(monitor.id)
    incident_status = determine_incident_status(open_incidents)

    new_status =
      [log_status, incident_status]
      |> Enum.max_by(&status_severity/1, fn -> :unknown end)

    if monitor.health_status != new_status do
      update_monitor(monitor, %{health_status: new_status})
    else
      {:ok, monitor}
    end
  end

  defp determine_incident_status([]), do: :unknown

  defp determine_incident_status(incidents) do
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

  defp status_from_latest_log(monitor_id) do
    log =
      Holter.Monitoring.MonitorLog
      |> where([l], l.monitor_id == ^monitor_id)
      |> order_by([l], desc: l.checked_at, desc: l.inserted_at)
      |> limit(1)
      |> Repo.one()

    if log, do: log.status, else: :unknown
  end

  def status_severity(:down), do: 4
  def status_severity(:compromised), do: 3
  def status_severity(:degraded), do: 2
  def status_severity(:up), do: 1
  def status_severity(_), do: 0

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
