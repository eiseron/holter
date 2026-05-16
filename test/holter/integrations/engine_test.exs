defmodule Holter.Integrations.EngineTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  import Mox

  alias Holter.Integrations.Engine
  alias Holter.Integrations.Workers.IntegrationDispatcher

  setup :verify_on_exit!

  describe "dispatch_event/2" do
    test "enqueues a job for each active integration subscribed to the event" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      _ig =
        integration_fixture(
          workspace_id: ws.id,
          subscribed_events: ["incident_opened"],
          status: :active
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      assert_enqueued(worker: IntegrationDispatcher, args: %{"event" => "incident_opened"})
    end

    test "does not enqueue jobs when no active integrations are subscribed" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      _ig =
        integration_fixture(
          workspace_id: ws.id,
          subscribed_events: ["incident_resolved"],
          status: :active
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      refute_enqueued(worker: IntegrationDispatcher)
    end

    test "skips disabled integrations" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      _ig =
        integration_fixture(
          workspace_id: ws.id,
          subscribed_events: ["incident_opened"],
          status: :disabled
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      refute_enqueued(worker: IntegrationDispatcher)
    end
  end
end
