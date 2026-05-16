defmodule Holter.Integrations.EventConsumerTest do
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias Holter.Integrations.Workers.IntegrationDispatcher

  setup do
    {:ok, pid} = start_supervised(Holter.Integrations.EventConsumer)
    Sandbox.allow(Holter.Repo, self(), pid)
    :ok
  end

  describe "incident_opened event" do
    test "enqueues IntegrationDispatcher job when active integration subscribes to the event" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      _ig =
        integration_fixture(
          workspace_id: ws.id,
          subscribed_events: ["incident_opened"],
          status: :active
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:incident_opened, incident}
      )

      Process.sleep(50)

      assert_enqueued(worker: IntegrationDispatcher, args: %{"event" => "incident_opened"})
    end

    test "does not enqueue jobs when no integration subscribes to incident_opened" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      _ig =
        integration_fixture(
          workspace_id: ws.id,
          subscribed_events: ["incident_resolved"],
          status: :active
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:incident_opened, incident}
      )

      Process.sleep(50)

      assert all_enqueued(queue: :integrations) == []
    end

    test "does not enqueue jobs for disabled integrations" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      _ig =
        integration_fixture(
          workspace_id: ws.id,
          subscribed_events: ["incident_opened"],
          status: :disabled
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:incident_opened, incident}
      )

      Process.sleep(50)

      assert all_enqueued(queue: :integrations) == []
    end
  end

  describe "incident_resolved event" do
    test "enqueues IntegrationDispatcher job when active integration subscribes to the event" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      _ig =
        integration_fixture(
          workspace_id: ws.id,
          subscribed_events: ["incident_resolved"],
          status: :active
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:incident_resolved, incident}
      )

      Process.sleep(50)

      assert_enqueued(worker: IntegrationDispatcher, args: %{"event" => "incident_resolved"})
    end
  end

  describe "unknown messages" do
    test "are silently ignored and GenServer remains alive" do
      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:unknown_event, %{id: Ecto.UUID.generate()}}
      )

      Process.sleep(50)

      assert all_enqueued(queue: :integrations) == []
    end
  end
end
