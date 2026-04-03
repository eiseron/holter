defmodule Holter.Monitoring.Workers.LogsPrunerTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring.{Monitor, MonitorLog, TenantLimit}
  alias Holter.Monitoring.Workers.LogsPruner

  setup do
    monitor =
      Repo.insert!(%Monitor{
        url: "https://test.com",
        method: :get,
        timeout_seconds: 5,
        interval_seconds: 60
      })

    %{monitor: monitor}
  end

  test "prunes logs correctly based on fallback retention days (3)", %{monitor: monitor} do
    old_date = DateTime.utc_now() |> DateTime.add(-4, :day) |> DateTime.truncate(:second)
    Repo.insert!(%MonitorLog{monitor_id: monitor.id, status: :success, checked_at: old_date})

    new_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
    Repo.insert!(%MonitorLog{monitor_id: monitor.id, status: :success, checked_at: new_date})

    assert Repo.aggregate(MonitorLog, :count, :id) == 2

    assert :ok = perform_job(LogsPruner, %{"monitor_id" => monitor.id})

    assert Repo.aggregate(MonitorLog, :count, :id) == 1
    assert Repo.one(MonitorLog).checked_at == new_date
  end

  test "prunes logs based on TenantLimit if owner exists", %{monitor: monitor} do
    user_id = Ecto.UUID.generate()
    monitor = monitor |> Ecto.Changeset.change(%{user_id: user_id}) |> Repo.update!()
    Repo.insert!(%TenantLimit{user_id: user_id, retention_days: 10})

    old_date = DateTime.utc_now() |> DateTime.add(-11, :day) |> DateTime.truncate(:second)
    mid_date = DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.truncate(:second)

    Repo.insert!(%MonitorLog{monitor_id: monitor.id, status: :success, checked_at: old_date})
    Repo.insert!(%MonitorLog{monitor_id: monitor.id, status: :success, checked_at: mid_date})

    assert :ok = perform_job(LogsPruner, %{"monitor_id" => monitor.id})

    assert Repo.aggregate(MonitorLog, :count, :id) == 1
    assert Repo.one(MonitorLog).checked_at == mid_date
  end

  test "self enqueues if deleted count hits chunk size", %{monitor: monitor} do
    now = DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.truncate(:second)

    entries =
      for _ <- 1..501 do
        %{
          id: Ecto.UUID.generate(),
          monitor_id: monitor.id,
          status: :success,
          checked_at: now,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(MonitorLog, entries)

    assert :ok = perform_job(LogsPruner, %{"monitor_id" => monitor.id})

    assert Repo.aggregate(MonitorLog, :count, :id) == 1
    assert_enqueued(worker: LogsPruner, args: %{"monitor_id" => monitor.id})
  end
end
