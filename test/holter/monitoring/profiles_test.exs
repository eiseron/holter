defmodule Holter.Monitoring.ProfilesTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring
  alias Holter.Monitoring.Profiles

  describe "consume_trigger_budget/1 short window" do
    test "increments trigger_short_count from 0 to 1 on a fresh profile" do
      profile = workspace_fixture(%{max_triggers_per_minute: 3}).monitoring_profile

      assert {:ok, %{trigger_short_count: 1}} = Profiles.consume_trigger_budget(profile)
    end

    test "returns short_budget_exhausted when minute cap is reached" do
      profile = exhausted_short_profile()

      assert {:error, :short_budget_exhausted} = Profiles.consume_trigger_budget(profile)
    end

    test "resets short count to 1 after short window expires" do
      past = DateTime.utc_now() |> DateTime.add(-61, :second) |> DateTime.truncate(:second)
      profile = set_short_window(exhausted_short_profile(), 1, past)

      assert {:ok, %{trigger_short_count: 1}} = Profiles.consume_trigger_budget(profile)
    end
  end

  describe "consume_trigger_budget/1 long window" do
    test "returns long_budget_exhausted when hourly cap is reached" do
      profile = exhausted_long_profile()

      assert {:error, :long_budget_exhausted} = Profiles.consume_trigger_budget(profile)
    end

    test "resets long count to 1 after long window expires" do
      past = DateTime.utc_now() |> DateTime.add(-3601, :second) |> DateTime.truncate(:second)
      profile = set_long_window(exhausted_long_profile(), 1, past)

      assert {:ok, %{trigger_long_count: 1}} = Profiles.consume_trigger_budget(profile)
    end
  end

  describe "mark_manual_check_triggered/1 budget integration" do
    test "returns short_budget_exhausted when minute cap is reached" do
      workspace = workspace_with_exhausted_short_trigger()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      assert {:error, :short_budget_exhausted} =
               Monitoring.mark_manual_check_triggered(monitor)
    end

    test "does not stamp last_manual_check_at when short budget exhausted" do
      workspace = workspace_with_exhausted_short_trigger()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      Monitoring.mark_manual_check_triggered(monitor)

      assert Monitoring.get_monitor!(monitor.id).last_manual_check_at == nil
    end

    test "returns long_budget_exhausted when hourly cap is reached" do
      workspace = workspace_with_exhausted_long_trigger()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      assert {:error, :long_budget_exhausted} =
               Monitoring.mark_manual_check_triggered(monitor)
    end

    test "does not stamp last_manual_check_at when long budget exhausted" do
      workspace = workspace_with_exhausted_long_trigger()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      Monitoring.mark_manual_check_triggered(monitor)

      assert Monitoring.get_monitor!(monitor.id).last_manual_check_at == nil
    end
  end

  describe "create_monitor/1 budget integration" do
    test "does not enqueue job when budget is exhausted on creation" do
      workspace = workspace_with_exhausted_short_trigger()

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
      workspace = workspace_with_exhausted_short_trigger()
      url = "https://second.example.com"
      ws_id = workspace.id

      assert {:ok, %{url: ^url, workspace_id: ^ws_id}} =
               Monitoring.create_monitor(%{
                 url: url,
                 method: :get,
                 interval_seconds: 60,
                 workspace_id: workspace.id
               })
    end
  end

  describe "consume_create_budget/1 short window" do
    test "increments create_short_count from 0 to 1 on a fresh profile" do
      profile = workspace_fixture(%{max_creates_per_minute: 5}).monitoring_profile

      assert {:ok, %{create_short_count: 1}} = Profiles.consume_create_budget(profile)
    end

    test "returns create_rate_limited when minute cap is reached" do
      profile = exhausted_short_create_profile()

      assert {:error, :create_rate_limited} = Profiles.consume_create_budget(profile)
    end

    test "resets create short count to 1 after short window expires" do
      past = DateTime.utc_now() |> DateTime.add(-61, :second) |> DateTime.truncate(:second)
      profile = set_create_short_window(exhausted_short_create_profile(), 1, past)

      assert {:ok, %{create_short_count: 1}} = Profiles.consume_create_budget(profile)
    end
  end

  describe "consume_create_budget/1 long window" do
    test "returns create_rate_limited when hourly cap is reached" do
      profile = exhausted_long_create_profile()

      assert {:error, :create_rate_limited} = Profiles.consume_create_budget(profile)
    end

    test "resets create long count to 1 after long window expires" do
      past = DateTime.utc_now() |> DateTime.add(-3601, :second) |> DateTime.truncate(:second)
      profile = set_create_long_window(exhausted_long_create_profile(), 1, past)

      assert {:ok, %{create_long_count: 1}} = Profiles.consume_create_budget(profile)
    end
  end

  describe "create_monitor/1 creation rate limiting" do
    test "returns create_rate_limited when minute cap is reached" do
      workspace = workspace_with_exhausted_short_create()

      assert {:error, :create_rate_limited} =
               Monitoring.create_monitor(%{
                 url: "https://rate-limited.example.com",
                 method: :get,
                 interval_seconds: 60,
                 workspace_id: workspace.id
               })
    end

    test "returns create_rate_limited when hourly cap is reached" do
      workspace = workspace_with_exhausted_long_create()

      assert {:error, :create_rate_limited} =
               Monitoring.create_monitor(%{
                 url: "https://rate-limited.example.com",
                 method: :get,
                 interval_seconds: 60,
                 workspace_id: workspace.id
               })
    end

    test "does not persist the monitor when minute cap is reached" do
      workspace = workspace_with_exhausted_short_create()

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
      workspace = workspace_with_exhausted_short_create()

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

  describe "at_monitor_quota?/2" do
    test "returns true when active monitor count >= max_monitors" do
      workspace = workspace_fixture(%{max_monitors: 1})
      monitor_fixture(%{workspace_id: workspace.id})

      assert Profiles.at_monitor_quota?(workspace.monitoring_profile)
    end

    test "ignores archived monitors when counting" do
      workspace = workspace_fixture(%{max_monitors: 1})
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      {:ok, _} = Monitoring.update_monitor(monitor, %{logical_state: :archived})

      refute Profiles.at_monitor_quota?(workspace.monitoring_profile)
    end

    test "exclude_monitor_id skips a row from the count" do
      workspace = workspace_fixture(%{max_monitors: 1})
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      refute Profiles.at_monitor_quota?(workspace.monitoring_profile, monitor.id)
    end
  end

  defp exhausted_short_create_profile do
    workspace_fixture(%{max_creates_per_minute: 1, max_creates_per_hour: 20}).monitoring_profile
    |> set_create_short_window(1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp exhausted_long_create_profile do
    workspace_fixture(%{max_creates_per_minute: 10, max_creates_per_hour: 1}).monitoring_profile
    |> set_create_long_window(1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp workspace_with_exhausted_short_create do
    workspace = workspace_fixture(%{max_creates_per_minute: 1, max_creates_per_hour: 20})

    set_create_short_window(
      workspace.monitoring_profile,
      1,
      DateTime.utc_now() |> DateTime.truncate(:second)
    )

    workspace
  end

  defp workspace_with_exhausted_long_create do
    workspace = workspace_fixture(%{max_creates_per_minute: 10, max_creates_per_hour: 1})

    set_create_long_window(
      workspace.monitoring_profile,
      1,
      DateTime.utc_now() |> DateTime.truncate(:second)
    )

    workspace
  end

  defp set_create_short_window(profile, count, start) do
    {:ok, updated} =
      profile
      |> Ecto.Changeset.cast(
        %{create_short_count: count, create_short_window_start: start},
        [:create_short_count, :create_short_window_start]
      )
      |> Holter.Repo.update()

    updated
  end

  defp set_create_long_window(profile, count, start) do
    {:ok, updated} =
      profile
      |> Ecto.Changeset.cast(
        %{create_long_count: count, create_long_window_start: start},
        [:create_long_count, :create_long_window_start]
      )
      |> Holter.Repo.update()

    updated
  end

  defp exhausted_short_profile do
    workspace_fixture(%{max_triggers_per_minute: 1, max_triggers_per_hour: 10}).monitoring_profile
    |> set_short_window(1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp exhausted_long_profile do
    workspace_fixture(%{max_triggers_per_minute: 10, max_triggers_per_hour: 1}).monitoring_profile
    |> set_long_window(1, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp workspace_with_exhausted_short_trigger do
    workspace = workspace_fixture(%{max_triggers_per_minute: 1, max_triggers_per_hour: 10})

    set_short_window(
      workspace.monitoring_profile,
      1,
      DateTime.utc_now() |> DateTime.truncate(:second)
    )

    workspace
  end

  defp workspace_with_exhausted_long_trigger do
    workspace = workspace_fixture(%{max_triggers_per_minute: 10, max_triggers_per_hour: 1})

    set_long_window(
      workspace.monitoring_profile,
      1,
      DateTime.utc_now() |> DateTime.truncate(:second)
    )

    workspace
  end

  defp set_short_window(profile, count, start) do
    {:ok, updated} =
      profile
      |> Ecto.Changeset.cast(
        %{trigger_short_count: count, trigger_short_window_start: start},
        [:trigger_short_count, :trigger_short_window_start]
      )
      |> Holter.Repo.update()

    updated
  end

  defp set_long_window(profile, count, start) do
    {:ok, updated} =
      profile
      |> Ecto.Changeset.cast(
        %{trigger_long_count: count, trigger_long_window_start: start},
        [:trigger_long_count, :trigger_long_window_start]
      )
      |> Holter.Repo.update()

    updated
  end
end
