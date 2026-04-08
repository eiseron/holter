defmodule Holter.MonitoringFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Holter.Monitoring` context.
  """

  def workspace_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Test Workspace",
        slug: "test-workspace-#{System.unique_integer([:positive])}",
        retention_days: 3,
        max_monitors: 3,
        min_interval_seconds: 60
      })

    {:ok, workspace} = Holter.Monitoring.create_workspace(attrs)

    workspace
  end

  def monitor_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    workspace_id =
      cond do
        id = attrs[:workspace_id] -> id
        id = attrs["workspace_id"] -> id
        workspace = attrs[:workspace] -> workspace.id
        true -> workspace_fixture().id
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

    monitor_id =
      cond do
        id = attrs[:monitor_id] -> id
        id = attrs["monitor_id"] -> id
        monitor = attrs[:monitor] -> monitor.id
        true -> monitor_fixture().id
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
end
