defmodule Holter.Monitoring.Monitors do
  @moduledoc false

  import Ecto.Query

  alias Holter.Monitoring.{
    Broadcaster,
    Incident,
    Incidents,
    Monitor,
    Pagination,
    Workspace,
    Workspaces
  }

  alias Holter.Monitoring.Workers.{HTTPCheck, SSLCheck}
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

    incident_counts =
      Incident
      |> where([i], i.monitor_id in ^monitor_ids and is_nil(i.resolved_at))
      |> group_by([i], i.monitor_id)
      |> select([i], {i.monitor_id, count(i.id)})
      |> Repo.all()
      |> Map.new()

    Enum.map(monitors, fn monitor ->
      %{
        monitor
        | logs: Map.get(logs_by_monitor, monitor.id, []),
          open_incidents_count: Map.get(incident_counts, monitor.id, 0)
      }
    end)
  end

  def get_monitor!(id), do: Repo.get!(Monitor, id)

  @doc """
  Counts monitors for a given workspace.
  """
  def count_monitors(workspace_id) do
    Monitor
    |> where(workspace_id: ^workspace_id)
    |> Repo.aggregate(:count, :id)
  end

  def get_monitor(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %Monitor{} = monitor <- Repo.get(Monitor, id) do
      {:ok, monitor}
    else
      _ -> {:error, :not_found}
    end
  end

  def list_monitors_filtered(params) do
    workspace_id = Map.fetch!(params, :workspace_id)
    page = Map.get(params, :page, 1) |> max(1)
    page_size = Pagination.resolve_page_size(Map.get(params, :page_size))

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
      |> Pagination.paginate_query(page, page_size)
      |> Repo.all()

    %{data: monitors, meta: %{page: page, page_size: page_size, total: total}}
  end

  def create_monitor(attrs \\ %{}) do
    workspace_id = attrs[:workspace_id] || attrs["workspace_id"]
    logical_state = attrs[:logical_state] || attrs["logical_state"] || :active

    with {:ok, workspace} <- fetch_workspace_for_quota(workspace_id),
         :ok <- check_monitor_quota(workspace, logical_state),
         {:ok, changeset} <- build_valid_changeset(attrs, workspace),
         :ok <- check_create_rate_limit(workspace, logical_state),
         {:ok, monitor} <- Repo.insert(changeset),
         {:ok, should_enqueue} <- check_trigger_budget(monitor, workspace) do
      if should_enqueue, do: enqueue_checks(monitor)
      Broadcaster.broadcast({:ok, monitor}, :monitor_created, monitor.id)
      {:ok, monitor}
    end
  end

  def enqueue_checks(%Monitor{} = monitor) do
    HTTPCheck.new(%{"id" => monitor.id}) |> Oban.insert()

    if String.starts_with?(monitor.url, "https") do
      SSLCheck.new(%{"id" => monitor.id}) |> Oban.insert()
    end

    :ok
  end

  def update_monitor(%Monitor{} = monitor, attrs) do
    proposed_checked_at = Map.get(attrs, :last_checked_at)

    if proposed_checked_at && monitor.last_checked_at &&
         DateTime.compare(monitor.last_checked_at, proposed_checked_at) == :gt do
      {:ok, monitor}
    else
      workspace = Repo.get!(Workspace, monitor.workspace_id)

      case monitor
           |> Monitor.changeset(attrs, workspace)
           |> Repo.update() do
        {:ok, updated} ->
          Broadcaster.broadcast({:ok, updated}, :monitor_updated, updated.id)
          {:ok, updated}

        error ->
          error
      end
    end
  end

  def at_quota?(%{max_monitors: max, id: ws_id}, exclude_monitor_id \\ nil) do
    query =
      Monitor
      |> where([m], m.workspace_id == ^ws_id)
      |> where([m], m.logical_state != :archived)

    query =
      if exclude_monitor_id do
        where(query, [m], m.id != ^exclude_monitor_id)
      else
        query
      end

    count = Repo.aggregate(query, :count, :id)
    count >= max
  end

  def mark_manual_check_triggered(%Monitor{} = monitor) do
    workspace = Repo.get!(Workspace, monitor.workspace_id)

    with {:ok, _} <- Workspaces.consume_trigger_budget(workspace) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      system_update_monitor(monitor, %{last_manual_check_at: now})
    end
  end

  def delete_monitor(%Monitor{} = monitor) do
    Repo.delete(monitor)
  end

  def change_monitor(%Monitor{} = monitor, attrs \\ %{}) do
    Monitor.changeset(monitor, attrs)
  end

  def change_monitor(%Monitor{} = monitor, attrs, workspace) do
    Monitor.changeset(monitor, attrs, workspace)
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
      system_update_monitor(monitor, %{health_status: new_status})
    else
      {:ok, monitor}
    end
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
      desc: fragment("CASE WHEN logical_state = 'paused' THEN 0 ELSE 1 END"),
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
      desc:
        fragment(
          "(SELECT COUNT(*) FROM incidents WHERE incidents.monitor_id = ? AND incidents.resolved_at IS NULL)",
          m.id
        ),
      desc: m.inserted_at
    )
  end

  defp check_create_rate_limit(_workspace, logical_state)
       when logical_state in [:archived, "archived"],
       do: :ok

  defp check_create_rate_limit(workspace, _logical_state) do
    case Workspaces.consume_create_budget(workspace) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp build_valid_changeset(attrs, workspace) do
    changeset = %Monitor{} |> Monitor.changeset(attrs, workspace)
    if changeset.valid?, do: {:ok, changeset}, else: {:error, changeset}
  end

  defp check_trigger_budget(monitor, workspace) do
    if monitor.logical_state == :active do
      case Workspaces.consume_trigger_budget(workspace) do
        {:ok, _} -> {:ok, true}
        {:error, _} -> {:ok, false}
      end
    else
      {:ok, false}
    end
  end

  defp fetch_workspace_for_quota(nil), do: {:error, :not_found}

  defp fetch_workspace_for_quota(id) do
    case Repo.get(Workspace, id) do
      nil -> {:error, :not_found}
      ws -> {:ok, ws}
    end
  end

  defp check_monitor_quota(workspace, logical_state) do
    if logical_state not in [:archived, "archived"] and at_quota?(workspace) do
      {:error, :quota_reached}
    else
      :ok
    end
  end

  defp system_update_monitor(%Monitor{} = monitor, attrs) do
    case monitor |> Monitor.changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        Broadcaster.broadcast({:ok, updated}, :monitor_updated, updated.id)
        {:ok, updated}

      error ->
        error
    end
  end

  defp determine_incident_status([]), do: :unknown

  defp determine_incident_status(incidents) do
    incidents
    |> Enum.map(&incident_to_health/1)
    |> Enum.max_by(&status_severity/1, fn -> :up end)
  end

  defp incident_to_health(incident), do: Incidents.incident_to_health(incident)

  defp status_from_latest_log(monitor_id) do
    log =
      Holter.Monitoring.MonitorLog
      |> where([l], l.monitor_id == ^monitor_id)
      |> order_by([l], desc: l.checked_at, desc: l.inserted_at)
      |> limit(1)
      |> Repo.one()

    if log, do: log.status, else: :unknown
  end
end
