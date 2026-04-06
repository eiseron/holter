defmodule Holter.Monitoring.MonitorsHealthTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring

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
