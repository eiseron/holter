defmodule Holter.Monitoring.Workers.LogsPrunerTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring.MonitorLog
  alias Holter.Monitoring.Workers.LogsPruner

  setup do
    workspace = workspace_fixture(%{retention_days: 3})

    monitor =
      monitor_fixture(%{
        url: "https://test.com",
        method: "get",
        timeout_seconds: 5,
        interval_seconds: 60,
        workspace_id: workspace.id
      })

    %{monitor: monitor, workspace: workspace}
  end

  describe "when pruning based on workspace retention days" do
    setup %{monitor: monitor} do
      old_date = DateTime.utc_now() |> DateTime.add(-4, :day) |> DateTime.truncate(:microsecond)

      Repo.insert!(%MonitorLog{
        monitor_id: monitor.id,
        status: :up,
        checked_at: old_date,
        inserted_at: old_date,
        updated_at: old_date
      })

      new_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:microsecond)

      Repo.insert!(%MonitorLog{
        monitor_id: monitor.id,
        status: :up,
        checked_at: new_date,
        inserted_at: new_date,
        updated_at: new_date
      })

      perform_job(LogsPruner, %{"monitor_id" => monitor.id})

      %{new_date: new_date}
    end

    test "deletes only old logs in db" do
      assert Repo.aggregate(MonitorLog, :count, :id) == 1
    end

    test "keeps precisely the newer logs", %{new_date: new_date} do
      assert Repo.one(MonitorLog).checked_at == new_date
    end
  end

  describe "when pruning based on custom workspace retention" do
    setup %{monitor: monitor, workspace: workspace} do
      {:ok, _} = Holter.Monitoring.update_workspace(workspace, %{retention_days: 10})

      old_date = DateTime.utc_now() |> DateTime.add(-11, :day) |> DateTime.truncate(:microsecond)
      mid_date = DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.truncate(:microsecond)

      Repo.insert!(%MonitorLog{
        monitor_id: monitor.id,
        status: :up,
        checked_at: old_date,
        inserted_at: old_date,
        updated_at: old_date
      })

      Repo.insert!(%MonitorLog{
        monitor_id: monitor.id,
        status: :up,
        checked_at: mid_date,
        inserted_at: mid_date,
        updated_at: mid_date
      })

      perform_job(LogsPruner, %{"monitor_id" => monitor.id})

      %{mid_date: mid_date}
    end

    test "deletes logs outside the 10 days retention" do
      assert Repo.aggregate(MonitorLog, :count, :id) == 1
    end

    test "keeps logs within the 10 days retention", %{mid_date: mid_date} do
      assert Repo.one(MonitorLog).checked_at == mid_date
    end
  end

  describe "when deleted count hits chunk size" do
    setup %{monitor: monitor} do
      now = DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.truncate(:microsecond)

      entries =
        for _ <- 1..501 do
          %{
            id: Ecto.UUID.generate(),
            monitor_id: monitor.id,
            status: :up,
            checked_at: now,
            inserted_at: now,
            updated_at: now
          }
        end

      Repo.insert_all(MonitorLog, entries)

      perform_job(LogsPruner, %{"monitor_id" => monitor.id})

      :ok
    end

    test "deletes strictly the chunk size volume leaving the rest" do
      assert Repo.aggregate(MonitorLog, :count, :id) == 1
    end

    test "self enqueues to continue next chunk", %{monitor: monitor} do
      assert_enqueued(worker: LogsPruner, args: %{"monitor_id" => monitor.id})
    end
  end
end
