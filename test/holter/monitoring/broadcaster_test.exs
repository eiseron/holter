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
end
