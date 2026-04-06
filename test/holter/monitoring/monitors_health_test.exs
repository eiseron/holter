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

  describe "recalculate_health_status/1 hierarchy" do
    test "returns :up when no incidents exist", %{monitor: monitor} do
      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :up
    end

    test "prefers :down over other statuses", %{monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :downtime,
        started_at: DateTime.utc_now()
      })

      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :ssl_expiry,
        started_at: DateTime.utc_now(),
        root_cause: "Critical"
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :down
    end

    test "prefers :compromised over :degraded", %{monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :ssl_expiry,
        started_at: DateTime.utc_now(),
        root_cause: "Warning"
      })

      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :defacement,
        started_at: DateTime.utc_now()
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :compromised
    end

    test "sets :degraded for SSL warning", %{monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :ssl_expiry,
        started_at: DateTime.utc_now(),
        root_cause: "Warning"
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :degraded
    end

    test "sets :compromised for SSL critical warning", %{monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :ssl_expiry,
        started_at: DateTime.utc_now(),
        root_cause: "Critical"
      })

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :compromised
    end

    test "restores :up when all incidents are resolved", %{monitor: monitor} do
      {:ok, incident} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :downtime,
          started_at: DateTime.utc_now() |> DateTime.add(-1, :hour)
        })

      Monitoring.resolve_incident(incident, DateTime.utc_now())

      {:ok, updated} = Monitoring.recalculate_health_status(monitor)
      assert updated.health_status == :up
    end
  end
end
