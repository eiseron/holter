defmodule Holter.Monitoring.Workers.MonitorDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.{DomainCheck, HTTPCheck, MonitorDispatcher, SSLCheck}

  setup do
    monitor = create_active_monitor()
    Holter.Repo.delete_all(Oban.Job)
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
      refute_enqueued(worker: SSLCheck, args: %{id: monitor.id})
    end
  end

  describe "perform/1 domain check dispatch" do
    test "enqueues DomainCheck on first dispatch for a public host", %{monitor: monitor} do
      :ok = MonitorDispatcher.perform(%Oban.Job{})

      assert_enqueued(worker: DomainCheck, args: %{id: monitor.id})
    end

    test "skips DomainCheck when domain_check_ignore is true", %{monitor: monitor} do
      Monitoring.update_monitor(monitor, %{domain_check_ignore: true})

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      refute_enqueued(worker: DomainCheck, args: %{id: monitor.id})
    end

    test "skips DomainCheck when last_domain_check_at is within 24h" do
      monitor = create_active_monitor_with_last_domain_check(-3600)

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      refute_enqueued(worker: DomainCheck, args: %{id: monitor.id})
    end

    test "enqueues DomainCheck when last_domain_check_at is older than 24h" do
      monitor = create_active_monitor_with_last_domain_check(-(25 * 3600))

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      assert_enqueued(worker: DomainCheck, args: %{id: monitor.id})
    end

    test "skips DomainCheck when monitor URL host is an IP literal" do
      monitor = create_active_monitor_with_url("http://1.1.1.1")

      :ok = MonitorDispatcher.perform(%Oban.Job{})

      refute_enqueued(worker: DomainCheck, args: %{id: monitor.id})
    end
  end

  defp create_active_monitor do
    workspace = workspace_fixture()

    {:ok, monitor} =
      Monitoring.create_monitor(%{
        url: "https://active.local",
        method: :get,
        interval_seconds: 60,
        logical_state: :active,
        workspace_id: workspace.id
      })

    monitor
  end

  defp create_active_monitor_with_last_domain_check(seconds_ago) do
    monitor = create_active_monitor()
    time = DateTime.utc_now() |> DateTime.add(seconds_ago, :second) |> DateTime.truncate(:second)
    {:ok, updated} = Monitoring.update_monitor(monitor, %{last_domain_check_at: time})
    updated
  end

  defp create_active_monitor_with_url(url) do
    workspace = workspace_fixture()

    {:ok, monitor} =
      Monitoring.create_monitor(%{
        url: url,
        method: :get,
        interval_seconds: 60,
        logical_state: :active,
        workspace_id: workspace.id
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
