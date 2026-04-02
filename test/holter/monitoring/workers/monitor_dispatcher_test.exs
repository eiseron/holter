defmodule Holter.Monitoring.Workers.MonitorDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.MonitorDispatcher
  alias Holter.Monitoring.Workers.HTTPCheck

  setup do
    monitor = create_active_monitor()
    %{monitor: monitor}
  end

  describe "perform/1 dispatching logic" do
    test "enqueues monitor when last_checked_at is null", %{monitor: monitor} do
      :ok = MonitorDispatcher.perform(%Oban.Job{})

      assert_enqueued_check(monitor.id)
    end

    test "enqueues monitor when last_checked_at is older than interval", %{monitor: monitor} do
      set_last_checked_at(monitor, -120)

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      assert_enqueued_check(monitor.id)
    end

    test "skips monitor when recently checked", %{monitor: monitor} do
      set_last_checked_at(monitor, 0)

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      refute_enqueued_check(monitor.id)
    end

    test "skips monitor when paused", %{monitor: monitor} do
      Monitoring.update_monitor(monitor, %{logical_state: :paused})

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      refute_enqueued_check(monitor.id)
    end

    test "skips SSLCheck enqueue when ssl_ignore is true", %{monitor: monitor} do
      Monitoring.update_monitor(monitor, %{ssl_ignore: true})

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      assert_enqueued(worker: HTTPCheck, args: %{id: monitor.id})
      refute_enqueued(worker: Holter.Monitoring.Workers.SSLCheck, args: %{id: monitor.id})
    end
  end

  defp create_active_monitor do
    {:ok, monitor} =
      Monitoring.create_monitor(%{
        url: "https://active.local",
        method: "GET",
        interval_seconds: 60,
        logical_state: :active
      })

    monitor
  end

  defp set_last_checked_at(monitor, seconds_ago) do
    time = DateTime.utc_now() |> DateTime.add(seconds_ago, :second)
    Monitoring.update_monitor(monitor, %{last_checked_at: time})
  end

  defp assert_enqueued_check(monitor_id) do
    assert_enqueued(worker: HTTPCheck, args: %{id: monitor_id})
  end

  defp refute_enqueued_check(monitor_id) do
    refute_enqueued(worker: HTTPCheck, args: %{id: monitor_id})
  end
end
