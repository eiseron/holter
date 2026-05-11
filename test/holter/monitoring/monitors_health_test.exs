defmodule Holter.Monitoring.MonitorsHealthTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitors

  describe "status_severity/1" do
    test ":down has severity 4" do
      assert Monitors.status_severity(:down) == 4
    end

    test ":compromised has severity 3" do
      assert Monitors.status_severity(:compromised) == 3
    end

    test ":degraded has severity 2" do
      assert Monitors.status_severity(:degraded) == 2
    end

    test ":up has severity 1" do
      assert Monitors.status_severity(:up) == 1
    end

    test ":unknown has severity 0" do
      assert Monitors.status_severity(:unknown) == 0
    end

    test ":down outranks :compromised" do
      assert Monitors.status_severity(:down) > Monitors.status_severity(:compromised)
    end

    test ":compromised outranks :degraded" do
      assert Monitors.status_severity(:compromised) > Monitors.status_severity(:degraded)
    end

    test ":degraded outranks :up" do
      assert Monitors.status_severity(:degraded) > Monitors.status_severity(:up)
    end

    test ":up outranks :unknown" do
      assert Monitors.status_severity(:up) > Monitors.status_severity(:unknown)
    end
  end

  setup do
    monitor =
      monitor_fixture(%{
        url: "https://example.com",
        method: "get",
        interval_seconds: 60,
        timeout_seconds: 30
      })

    %{monitor: monitor}
  end

  describe "recalculate_health_status/1" do
    test "returns :unknown when no logs exist", %{monitor: monitor} do
      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :unknown
    end

    test "reflects status of latest log (:up)", %{monitor: monitor} do
      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        checked_at: DateTime.utc_now() |> DateTime.add(-10, :second)
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :up
    end

    test "reflects status of latest log (:down)", %{monitor: monitor} do
      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        checked_at: DateTime.utc_now() |> DateTime.add(-20, :second)
      })

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :down,
        checked_at: DateTime.utc_now() |> DateTime.add(-10, :second)
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :down
    end

    test "reflects status of latest log (:compromised)", %{monitor: monitor} do
      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :compromised,
        checked_at: DateTime.utc_now()
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :compromised
    end

    test "reflects status of latest log (:degraded)", %{monitor: monitor} do
      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :degraded,
        checked_at: DateTime.utc_now()
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :degraded
    end
  end
end
