defmodule Holter.Monitoring.WorkspaceBudgetTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring
  alias Holter.Monitoring.Workspaces

  describe "consume_trigger_budget/1 short window" do
    test "succeeds on a fresh workspace" do
      workspace = workspace_fixture(%{max_triggers_per_minute: 3})

      assert {:ok, _} = Workspaces.consume_trigger_budget(workspace)
    end

    test "returns short_budget_exhausted when minute cap is reached" do
      workspace = exhausted_short_workspace()

      assert {:error, :short_budget_exhausted} = Workspaces.consume_trigger_budget(workspace)
    end

    test "resets count after short window expires" do
      past = DateTime.utc_now() |> DateTime.add(-61, :second) |> DateTime.truncate(:second)
      workspace = set_short_window(exhausted_short_workspace(), 1, past)

      assert {:ok, _} = Workspaces.consume_trigger_budget(workspace)
    end
  end

  describe "consume_trigger_budget/1 long window" do
    test "returns long_budget_exhausted when hourly cap is reached" do
      workspace = exhausted_long_workspace()

      assert {:error, :long_budget_exhausted} = Workspaces.consume_trigger_budget(workspace)
    end

    test "resets count after long window expires" do
      past = DateTime.utc_now() |> DateTime.add(-3601, :second) |> DateTime.truncate(:second)
      workspace = set_long_window(exhausted_long_workspace(), 1, past)

      assert {:ok, _} = Workspaces.consume_trigger_budget(workspace)
    end
  end

  describe "mark_manual_check_triggered/1 budget integration" do
    test "returns short_budget_exhausted when minute cap is reached" do
      workspace = exhausted_short_workspace()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      assert {:error, :short_budget_exhausted} = Monitoring.mark_manual_check_triggered(monitor)
    end

    test "does not stamp last_manual_check_at when short budget exhausted" do
      workspace = exhausted_short_workspace()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      Monitoring.mark_manual_check_triggered(monitor)

      assert Monitoring.get_monitor!(monitor.id).last_manual_check_at == nil
    end

    test "returns long_budget_exhausted when hourly cap is reached" do
      workspace = exhausted_long_workspace()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      assert {:error, :long_budget_exhausted} = Monitoring.mark_manual_check_triggered(monitor)
    end

    test "does not stamp last_manual_check_at when long budget exhausted" do
      workspace = exhausted_long_workspace()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      Monitoring.mark_manual_check_triggered(monitor)

      assert Monitoring.get_monitor!(monitor.id).last_manual_check_at == nil
    end
  end

  describe "create_monitor/1 budget integration" do
    test "does not enqueue job when budget is exhausted on creation" do
      workspace = exhausted_short_workspace()

      {:ok, monitor} =
        Monitoring.create_monitor(%{
          url: "https://second.example.com",
          method: :get,
          interval_seconds: 60,
          workspace_id: workspace.id
        })

      refute_enqueued(worker: Holter.Monitoring.Workers.HTTPCheck, args: %{id: monitor.id})
    end

    test "creates monitor even when budget is exhausted" do
      workspace = exhausted_short_workspace()

      assert {:ok, _} =
               Monitoring.create_monitor(%{
                 url: "https://second.example.com",
                 method: :get,
                 interval_seconds: 60,
                 workspace_id: workspace.id
               })
    end
  end

  describe "consume_create_budget/1 short window" do
    test "succeeds on a fresh workspace" do
      workspace = workspace_fixture(%{max_creates_per_minute: 5})

      assert {:ok, _} = Workspaces.consume_create_budget(workspace)
    end

    test "returns create_rate_limited when minute cap is reached" do
      workspace = exhausted_short_create_workspace()

      assert {:error, :create_rate_limited} = Workspaces.consume_create_budget(workspace)
    end

    test "resets count after short window expires" do
      past = DateTime.utc_now() |> DateTime.add(-61, :second) |> DateTime.truncate(:second)
      workspace = set_create_short_window(exhausted_short_create_workspace(), 1, past)

      assert {:ok, _} = Workspaces.consume_create_budget(workspace)
    end
  end

  describe "consume_create_budget/1 long window" do
    test "returns create_rate_limited when hourly cap is reached" do
      workspace = exhausted_long_create_workspace()

      assert {:error, :create_rate_limited} = Workspaces.consume_create_budget(workspace)
    end

    test "resets count after long window expires" do
      past = DateTime.utc_now() |> DateTime.add(-3601, :second) |> DateTime.truncate(:second)
      workspace = set_create_long_window(exhausted_long_create_workspace(), 1, past)

      assert {:ok, _} = Workspaces.consume_create_budget(workspace)
    end
  end

  describe "create_monitor/1 creation rate limiting" do
    test "returns create_rate_limited when minute cap is reached" do
      workspace = exhausted_short_create_workspace()

      assert {:error, :create_rate_limited} =
               Monitoring.create_monitor(%{
                 url: "https://rate-limited.example.com",
                 method: :get,
                 interval_seconds: 60,
                 workspace_id: workspace.id
               })
    end

    test "returns create_rate_limited when hourly cap is reached" do
      workspace = exhausted_long_create_workspace()

      assert {:error, :create_rate_limited} =
               Monitoring.create_monitor(%{
                 url: "https://rate-limited.example.com",
                 method: :get,
                 interval_seconds: 60,
                 workspace_id: workspace.id
               })
    end

    test "does not persist the monitor when minute cap is reached" do
      workspace = exhausted_short_create_workspace()

      {:error, :create_rate_limited} =
        Monitoring.create_monitor(%{
          url: "https://rate-limited-no-persist.example.com",
          method: :get,
          interval_seconds: 60,
          workspace_id: workspace.id
        })

      assert Monitoring.list_monitors_by_workspace(workspace.id) == []
    end

    test "bypasses create budget for archived monitors" do
      workspace = exhausted_short_create_workspace()

      assert {:ok, _} =
               Monitoring.create_monitor(%{
                 url: "https://archived.example.com",
                 method: :get,
                 interval_seconds: 60,
                 logical_state: :archived,
                 workspace_id: workspace.id
               })
    end
  end

  defp exhausted_short_create_workspace do
    workspace = workspace_fixture(%{max_creates_per_minute: 1, max_creates_per_hour: 20})
    set_create_short_window(workspace, 1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp exhausted_long_create_workspace do
    workspace = workspace_fixture(%{max_creates_per_minute: 10, max_creates_per_hour: 1})
    set_create_long_window(workspace, 1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp set_create_short_window(workspace, count, start) do
    {:ok, updated} =
      workspace
      |> Ecto.Changeset.cast(
        %{create_short_count: count, create_short_window_start: start},
        [:create_short_count, :create_short_window_start]
      )
      |> Holter.Repo.update()

    updated
  end

  defp set_create_long_window(workspace, count, start) do
    {:ok, updated} =
      workspace
      |> Ecto.Changeset.cast(
        %{create_long_count: count, create_long_window_start: start},
        [:create_long_count, :create_long_window_start]
      )
      |> Holter.Repo.update()

    updated
  end

  defp exhausted_short_workspace do
    workspace = workspace_fixture(%{max_triggers_per_minute: 1, max_triggers_per_hour: 10})
    set_short_window(workspace, 1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp exhausted_long_workspace do
    workspace = workspace_fixture(%{max_triggers_per_minute: 10, max_triggers_per_hour: 1})
    set_long_window(workspace, 1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp set_short_window(workspace, count, start) do
    {:ok, updated} =
      workspace
      |> Ecto.Changeset.cast(
        %{trigger_short_count: count, trigger_short_window_start: start},
        [:trigger_short_count, :trigger_short_window_start]
      )
      |> Holter.Repo.update()

    updated
  end

  defp set_long_window(workspace, count, start) do
    {:ok, updated} =
      workspace
      |> Ecto.Changeset.cast(
        %{trigger_long_count: count, trigger_long_window_start: start},
        [:trigger_long_count, :trigger_long_window_start]
      )
      |> Holter.Repo.update()

    updated
  end
end
