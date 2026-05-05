defmodule Holter.Monitoring.BroadcasterTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.Broadcaster

  describe "broadcast/3 with {:ok, entity}" do
    test "broadcasts to monitor-specific topic" do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:test-id-1")
      entity = %{id: 1, monitor_id: "test-id-1"}
      Broadcaster.broadcast({:ok, entity}, :log_created, "test-id-1")
      assert_receive {:log_created, ^entity}
    end

    test "broadcasts to global monitors topic" do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitors")
      entity = %{id: 2, monitor_id: "test-id-2"}
      Broadcaster.broadcast({:ok, entity}, :monitor_updated, "test-id-2")
      assert_receive {:monitor_updated, ^entity}
    end

    test "returns {:ok, entity}" do
      entity = %{id: 3, monitor_id: "test-id-3"}
      assert Broadcaster.broadcast({:ok, entity}, :log_created, "test-id-3") == {:ok, entity}
    end
  end

  describe "broadcast/3 with error" do
    test "passes through the error unchanged" do
      assert Broadcaster.broadcast({:error, :invalid}, :log_created, "x") == {:error, :invalid}
    end

    test "passes through changeset error" do
      error = {:error, %Ecto.Changeset{}}
      assert Broadcaster.broadcast(error, :log_created, "x") == error
    end
  end

  describe "broadcast_incident_opened/1" do
    test "publishes :incident_opened on the monitoring:incidents topic" do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:incidents")
      incident = %{id: "inc-bc-opened-#{System.unique_integer([:positive])}", type: :downtime}

      Broadcaster.broadcast_incident_opened(incident)

      assert_receive {:incident_opened, ^incident}
    end

    test "does not echo the same incident as :incident_resolved" do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:incidents")
      id = "inc-bc-no-echo-r-#{System.unique_integer([:positive])}"
      incident = %{id: id, type: :ssl_expiry}

      Broadcaster.broadcast_incident_opened(incident)

      refute_receive {:incident_resolved, %{id: ^id}}, 50
    end
  end

  describe "broadcast_incident_resolved/1" do
    test "publishes :incident_resolved on the monitoring:incidents topic" do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:incidents")

      incident = %{
        id: "inc-bc-resolved-#{System.unique_integer([:positive])}",
        type: :downtime,
        resolved_at: ~U[2026-01-01 00:00:00Z]
      }

      Broadcaster.broadcast_incident_resolved(incident)

      assert_receive {:incident_resolved, ^incident}
    end

    test "does not echo the same incident as :incident_opened" do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:incidents")
      id = "inc-bc-no-echo-o-#{System.unique_integer([:positive])}"
      incident = %{id: id, type: :defacement}

      Broadcaster.broadcast_incident_resolved(incident)

      refute_receive {:incident_opened, %{id: ^id}}, 50
    end
  end
end
