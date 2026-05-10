defmodule Holter.Monitoring.Monitors do
  @moduledoc """
  Coordinator for the `monitors` table.

  Public functions assume the caller has already stamped the tenant via
  one of the entry-point macros (`HolterWeb.LiveTenancy`,
  `HolterWeb.ApiTenancy`, or
  `Holter.Monitoring.Workers.WorkspaceScopedWorker`). Each macro wraps
  the whole callback in `Holter.Repo.Tenant.with_workspace!/2`, so by
  the time control reaches a coordinator the RLS session var is
  already set under the `holter_app` role and the policy on `monitors`
  (`tenant_isolation`, keyed on `app.current_workspace_id`) sees the
  right tenant.

  Callers running outside a boundary (mix tasks, IEx, scripts,
  cross-workspace workers like `MonitorDispatcher` that iterate
  workspaces) must stamp explicitly. Forgetting to stamp produces
  empty results from RLS, which surfaces as `:not_found` or zero
  counts — never a cross-tenant leak.

  Every public function (other than the system-only entry points
  marked with the `:system` actor) takes an `actor` as its first
  argument and is expected to delegate the role decision to
  `Holter.Authorization`. RLS remains enabled as defence in depth.

  `list_monitors/1` and `list_monitors_for_dispatch/2` accept only the
  `:system` actor: they support `MonitorDispatcher`, which iterates the
  global `workspaces` table and re-stamps tenant per row before
  delegating back into per-workspace reads.
  """

  import Ecto.Query

  alias Holter.Authorization
  alias Holter.Identity.Tenant, as: IdentityTenant

  alias Holter.Monitoring.{Broadcaster, Incidents, Pagination, Workspaces}

  alias Holter.Monitoring.Models.{Incident, Monitor, Workspace}
  alias Holter.Monitoring.Workers.{HTTPCheck, SSLCheck}
  alias Holter.Repo

  def list_monitors(:system) do
    Repo.all(Monitor)
  end

  def list_monitors_by_workspace(actor, workspace_id) do
    if can_access_workspace?(actor, :read, workspace_id) do
      Monitor
      |> where([m], m.workspace_id == ^workspace_id)
      |> tactical_ranking()
      |> Repo.all()
    else
      []
    end
  end

  def list_monitors_with_sparklines(actor, workspace_id, log_limit \\ 30) do
    if can_access_workspace?(actor, :read, workspace_id) do
      do_list_monitors_with_sparklines(workspace_id, log_limit)
    else
      []
    end
  end

  def get_monitor!(actor, id) do
    monitor = Repo.get!(Monitor, id)

    case Authorization.authorize(actor, :read, monitor) do
      :ok -> monitor
      {:error, :forbidden} -> raise Ecto.NoResultsError, queryable: Monitor
    end
  end

  def count_monitors(actor, workspace_id) do
    if can_access_workspace?(actor, :read, workspace_id) do
      Monitor
      |> where(workspace_id: ^workspace_id)
      |> Repo.aggregate(:count, :id)
    else
      0
    end
  end

  def get_monitor(actor, id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %Monitor{} = monitor <- Repo.get(Monitor, id),
         :ok <- Authorization.authorize(actor, :read, monitor) do
      {:ok, monitor}
    else
      {:error, :forbidden} -> {:error, :not_found}
      _ -> {:error, :not_found}
    end
  end

  def list_monitors_filtered(actor, params) do
    workspace_id = Map.fetch!(params, :workspace_id)

    if can_access_workspace?(actor, :read, workspace_id) do
      do_list_monitors_filtered(workspace_id, params)
    else
      page = Map.get(params, :page, 1) |> max(1)
      page_size = Pagination.resolve_page_size(Map.get(params, :page_size))
      %{data: [], meta: %{page: page, page_size: page_size, total: 0}}
    end
  end

  def create_monitor(actor, attrs \\ %{}) do
    workspace_id = attrs[:workspace_id] || attrs["workspace_id"]

    with {:ok, _} <- IdentityTenant.parse_workspace_id(workspace_id),
         :ok <- authorize_workspace(actor, :write, workspace_id) do
      do_create_monitor(attrs, workspace_id)
    else
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, _} -> {:error, :not_found}
    end
  end

  def enqueue_checks(actor, %Monitor{} = monitor) do
    with :ok <- Authorization.authorize(actor, :write, monitor) do
      args = %{"id" => monitor.id, "workspace_id" => monitor.workspace_id}
      HTTPCheck.new(args) |> Oban.insert()

      if String.starts_with?(monitor.url, "https") do
        SSLCheck.new(args) |> Oban.insert()
      end

      :ok
    end
  end

  def update_monitor(actor, %Monitor{} = monitor, attrs) do
    with :ok <- Authorization.authorize(actor, :write, monitor) do
      do_update_monitor(monitor, attrs)
    end
  end

  def at_quota?(actor, %{max_monitors: max, id: ws_id} = workspace, exclude_monitor_id \\ nil) do
    if can_access_workspace?(actor, :read, workspace) do
      do_at_quota?(max, ws_id, exclude_monitor_id)
    else
      false
    end
  end

  def mark_manual_check_triggered(actor, %Monitor{} = monitor) do
    with :ok <- Authorization.authorize(actor, :write, monitor) do
      workspace = Repo.get!(Workspace, monitor.workspace_id)

      with {:ok, _} <- Workspaces.consume_trigger_budget(workspace) do
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        system_update_monitor(monitor, %{last_manual_check_at: now})
      end
    end
  end

  def delete_monitor(actor, %Monitor{} = monitor) do
    with :ok <- Authorization.authorize(actor, :delete, monitor) do
      Repo.delete(monitor)
    end
  end

  def change_monitor(%Monitor{} = monitor, attrs \\ %{}) do
    Monitor.changeset(monitor, attrs)
  end

  def change_monitor(%Monitor{} = monitor, attrs, workspace) do
    Monitor.changeset(monitor, attrs, workspace)
  end

  def recalculate_health_status(actor, %Monitor{} = monitor) do
    with :ok <- Authorization.authorize(actor, :write, monitor) do
      do_recalculate_health_status(monitor)
    end
  end

  def status_severity(:down), do: 4
  def status_severity(:compromised), do: 3
  def status_severity(:degraded), do: 2
  def status_severity(:up), do: 1
  def status_severity(_), do: 0

  def list_monitors_for_dispatch(:system, workspace_id) do
    now = DateTime.utc_now()

    Monitor
    |> where([m], m.workspace_id == ^workspace_id and m.logical_state == :active)
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

  defp do_create_monitor(attrs, workspace_id) do
    logical_state = attrs[:logical_state] || attrs["logical_state"] || :active

    with {:ok, workspace} <- fetch_workspace_for_quota(workspace_id),
         :ok <- check_monitor_quota(workspace, logical_state),
         {:ok, changeset} <- build_valid_changeset(attrs, workspace),
         :ok <- check_create_rate_limit(workspace, logical_state),
         {:ok, monitor} <- Repo.insert(changeset),
         {:ok, should_enqueue} <- check_trigger_budget(monitor, workspace) do
      if should_enqueue, do: enqueue_checks(:system, monitor)
      Broadcaster.broadcast({:ok, monitor}, :monitor_created, monitor.id)
      {:ok, monitor}
    end
  end

  defp do_update_monitor(monitor, attrs) do
    proposed_checked_at = Map.get(attrs, :last_checked_at)

    if stale_proposed_check?(monitor, proposed_checked_at) do
      {:ok, monitor}
    else
      apply_monitor_update(monitor, attrs)
    end
  end

  defp stale_proposed_check?(monitor, proposed_checked_at) do
    proposed_checked_at && monitor.last_checked_at &&
      DateTime.compare(monitor.last_checked_at, proposed_checked_at) == :gt
  end

  defp apply_monitor_update(monitor, attrs) do
    workspace = Repo.get!(Workspace, monitor.workspace_id)

    case monitor |> Monitor.changeset(attrs, workspace) |> Repo.update() do
      {:ok, updated} ->
        Broadcaster.broadcast({:ok, updated}, :monitor_updated, updated.id)
        {:ok, updated}

      error ->
        error
    end
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
    if logical_state not in [:archived, "archived"] and at_quota?(:system, workspace) do
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
      Holter.Monitoring.Models.MonitorLog
      |> where([l], l.monitor_id == ^monitor_id)
      |> order_by([l], desc: l.checked_at, desc: l.inserted_at)
      |> limit(1)
      |> Repo.one()

    if log, do: log.status, else: :unknown
  end

  defp do_list_monitors_filtered(workspace_id, params) do
    page = Map.get(params, :page, 1) |> max(1)
    page_size = Pagination.resolve_page_size(Map.get(params, :page_size))
    base_query = where(Monitor, [m], m.workspace_id == ^workspace_id)

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

  defp do_list_monitors_with_sparklines(workspace_id, log_limit) do
    monitors =
      Monitor
      |> where([m], m.workspace_id == ^workspace_id)
      |> tactical_ranking()
      |> Repo.all()

    monitor_ids = Enum.map(monitors, & &1.id)

    logs_by_monitor =
      Holter.Monitoring.Models.MonitorLog
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

  defp do_recalculate_health_status(monitor) do
    monitor = Repo.get!(Monitor, monitor.id)
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

  defp do_at_quota?(max, ws_id, exclude_monitor_id) do
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

  defp authorize_workspace(actor, action, workspace_or_id) do
    Authorization.authorize(actor, action, intent_for_workspace(workspace_or_id))
  end

  defp can_access_workspace?(actor, action, workspace_or_id) do
    Authorization.can?(actor, action, intent_for_workspace(workspace_or_id))
  end

  defp intent_for_workspace(%Workspace{} = workspace), do: {Monitor, workspace}

  defp intent_for_workspace(%{id: id}) when is_binary(id),
    do: {Monitor, %Workspace{id: id}}

  defp intent_for_workspace(id) when is_binary(id),
    do: {Monitor, %Workspace{id: id}}
end
