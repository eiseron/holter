defmodule Holter.MonitoringFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Holter.Monitoring` context.

  When a workspace-scoped fixture is called with `owner: %User{}`, the
  user is granted membership of the new workspace so that LiveView
  tests pass the `:require_workspace_member` gate.
  """

  alias Holter.Identity.Memberships

  def workspace_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    default_owner = Process.get(:current_test_user)
    {owner, attrs} = Map.pop(attrs, :owner, default_owner)

    workspace_attrs =
      Enum.into(attrs, %{
        name: "Test Workspace",
        slug: "test-workspace-#{System.unique_integer([:positive])}",
        retention_days: 3,
        max_monitors: 3,
        min_interval_seconds: 60
      })

    {:ok, workspace} = Holter.Monitoring.create_workspace(workspace_attrs)
    grant_membership(owner, workspace)

    workspace
  end

  def monitor_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {owner, attrs} = Map.pop(attrs, :owner, Process.get(:current_test_user))

    workspace_id =
      cond do
        id = attrs[:workspace_id] -> id
        id = attrs["workspace_id"] -> id
        workspace = attrs[:workspace] -> workspace.id
        true -> workspace_fixture(owner: owner).id
      end

    attrs =
      %{
        url: "https://example.com",
        method: "get",
        interval_seconds: 60,
        timeout_seconds: 30,
        workspace_id: workspace_id
      }
      |> Map.merge(attrs)

    {:ok, monitor} = Holter.Monitoring.create_monitor(attrs)

    monitor
  end

  def log_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {owner, attrs} = Map.pop(attrs, :owner, Process.get(:current_test_user))

    monitor_id =
      cond do
        id = attrs[:monitor_id] -> id
        id = attrs["monitor_id"] -> id
        monitor = attrs[:monitor] -> monitor.id
        true -> monitor_fixture(owner: owner).id
      end

    attrs =
      %{
        monitor_id: monitor_id,
        status: :up,
        latency_ms: Enum.random(50..500),
        checked_at: DateTime.utc_now()
      }
      |> Map.merge(attrs)

    {:ok, log} = Holter.Monitoring.create_monitor_log(attrs)

    log
  end

  def monitor_log_fixture(attrs), do: log_fixture(attrs)

  def daily_metric_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {owner, attrs} = Map.pop(attrs, :owner, Process.get(:current_test_user))

    monitor_id =
      cond do
        id = attrs[:monitor_id] -> id
        monitor = attrs[:monitor] -> monitor.id
        true -> monitor_fixture(owner: owner).id
      end

    attrs =
      %{
        monitor_id: monitor_id,
        date: Date.utc_today(),
        uptime_percent: 100.0,
        avg_latency_ms: 200,
        total_downtime_minutes: 0
      }
      |> Map.merge(attrs)

    {:ok, metric} = Holter.Monitoring.upsert_daily_metric(attrs)

    metric
  end

  def incident_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {owner, attrs} = Map.pop(attrs, :owner, Process.get(:current_test_user))

    monitor_id =
      cond do
        id = attrs[:monitor_id] -> id
        monitor = attrs[:monitor] -> monitor.id
        true -> monitor_fixture(owner: owner).id
      end

    attrs =
      %{
        monitor_id: monitor_id,
        type: :downtime,
        started_at: DateTime.utc_now(),
        monitor_snapshot: %{"url" => "https://example.com"}
      }
      |> Map.merge(attrs)

    {:ok, incident} = Holter.Monitoring.create_incident(attrs)

    incident
  end

  defp grant_membership(nil, _workspace), do: :ok

  defp grant_membership(owner, workspace) do
    {:ok, _} = Memberships.create_default_membership(owner, workspace)
    :ok
  end
end
