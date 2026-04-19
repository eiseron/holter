defmodule HolterWeb.LiveView.PubSubSubscriptionsTest do
  use ExUnit.Case, async: true

  alias HolterWeb.LiveView.PubSubSubscriptions

  @disconnected_socket %Phoenix.LiveView.Socket{}

  describe "subscribe_to_monitor/2" do
    test "returns :ok for a disconnected socket" do
      assert PubSubSubscriptions.subscribe_to_monitor(@disconnected_socket, "monitor-id") == :ok
    end

    test "does not subscribe when socket is disconnected" do
      unique_topic = "monitoring:monitor:test-skip-#{System.unique_integer([:positive])}"
      Phoenix.PubSub.subscribe(Holter.PubSub, unique_topic)
      id = String.replace_prefix(unique_topic, "monitoring:monitor:", "")
      PubSubSubscriptions.subscribe_to_monitor(@disconnected_socket, id)
      refute_receive {_, _}
    end
  end

  describe "subscribe_to_monitors/1" do
    test "returns :ok for a disconnected socket" do
      assert PubSubSubscriptions.subscribe_to_monitors(@disconnected_socket) == :ok
    end
  end
end
