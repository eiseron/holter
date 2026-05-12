defmodule Holter.Monitoring.Profiles do
  @moduledoc """
  Coordinator for the Monitoring bounded context's per-workspace
  configuration aggregate. Owns `max_monitors`, retention, the trigger
  and create rate-limit budgets, and the windowed counters that back
  them.

  Decoupled from `Holter.Monitoring.Models.Workspace` so Workspace can
  remain a thin tenant identity. Delivery has a parallel aggregate at
  `Holter.Delivery.Models.WorkspaceProfile`.
  """

  import Ecto.Query

  alias Holter.Monitoring.Models.WorkspaceProfile
  alias Holter.Repo

  def get_for_workspace!(workspace_id) do
    Repo.get_by!(WorkspaceProfile, workspace_id: workspace_id)
  end

  def get_for_workspace(workspace_id) do
    case Repo.get_by(WorkspaceProfile, workspace_id: workspace_id) do
      nil -> {:error, :not_found}
      profile -> {:ok, profile}
    end
  end

  def update_profile(%WorkspaceProfile{} = profile, attrs) do
    profile
    |> WorkspaceProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Reserves one slot in the trigger budget for `profile.workspace_id`.

  Coordinator: reads `DateTime.utc_now/0` once at the top, calls pure
  transformers to compute the next window state, then writes back via
  `Repo.update/1`.
  """
  def consume_trigger_budget(%WorkspaceProfile{} = profile) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    short =
      compute_window_state(
        %{count: profile.trigger_short_count, start: profile.trigger_short_window_start},
        now,
        WorkspaceProfile.trigger_short_window_seconds()
      )

    long =
      compute_window_state(
        %{count: profile.trigger_long_count, start: profile.trigger_long_window_start},
        now,
        WorkspaceProfile.trigger_long_window_seconds()
      )

    cond do
      short.count >= profile.max_triggers_per_minute ->
        {:error, :short_budget_exhausted}

      long.count >= profile.max_triggers_per_hour ->
        {:error, :long_budget_exhausted}

      true ->
        apply_budget_update(profile, %{
          trigger_short_count: short.count + 1,
          trigger_short_window_start: short.start,
          trigger_long_count: long.count + 1,
          trigger_long_window_start: long.start
        })
    end
  end

  @doc """
  Reserves one slot in the monitor-create budget for
  `profile.workspace_id`. Same shape as `consume_trigger_budget/1` but
  for the create rate limit.
  """
  def consume_create_budget(%WorkspaceProfile{} = profile) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    short =
      compute_window_state(
        %{count: profile.create_short_count, start: profile.create_short_window_start},
        now,
        WorkspaceProfile.create_short_window_seconds()
      )

    long =
      compute_window_state(
        %{count: profile.create_long_count, start: profile.create_long_window_start},
        now,
        WorkspaceProfile.create_long_window_seconds()
      )

    cond do
      short.count >= profile.max_creates_per_minute ->
        {:error, :create_rate_limited}

      long.count >= profile.max_creates_per_hour ->
        {:error, :create_rate_limited}

      true ->
        apply_budget_update(profile, %{
          create_short_count: short.count + 1,
          create_short_window_start: short.start,
          create_long_count: long.count + 1,
          create_long_window_start: long.start
        })
    end
  end

  @doc """
  Returns `true` when the workspace has reached `max_monitors`.

  Counts only non-archived monitors. Optional `exclude_monitor_id`
  skips a row from the count, used when re-activating an existing
  monitor that would otherwise count itself.
  """
  def at_monitor_quota?(%WorkspaceProfile{} = profile, exclude_monitor_id \\ nil) do
    monitor_query =
      from m in Holter.Monitoring.Models.Monitor,
        where: m.workspace_id == ^profile.workspace_id,
        where: m.logical_state != :archived

    monitor_query =
      if exclude_monitor_id do
        from m in monitor_query, where: m.id != ^exclude_monitor_id
      else
        monitor_query
      end

    Repo.aggregate(monitor_query, :count, :workspace_id) >= profile.max_monitors
  end

  defp compute_window_state(%{count: count, start: window_start}, now, window_seconds) do
    if window_start && DateTime.diff(now, window_start) < window_seconds do
      %{count: count, start: window_start}
    else
      %{count: 0, start: now}
    end
  end

  defp apply_budget_update(%WorkspaceProfile{} = profile, fields) do
    profile
    |> Ecto.Changeset.cast(fields, Map.keys(fields))
    |> Repo.update()
  end
end
