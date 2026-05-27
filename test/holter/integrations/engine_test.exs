defmodule Holter.Integrations.EngineTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Integrations.Engine
  alias Holter.Integrations.Workers.IntegrationDispatcher

  describe "dispatch_event/2" do
    test "enqueues a job when a binding exists for the (monitor, event) pair" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      integration = integration_fixture(workspace_id: ws.id, status: :active)

      _binding =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-111"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      assert_enqueued(worker: IntegrationDispatcher, args: %{"event" => "incident_opened"})
    end

    test "does not enqueue when no binding exists for the event" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      integration = integration_fixture(workspace_id: ws.id, status: :active)

      _binding =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_resolved",
          action: "pause_campaign",
          target_id: "gads-222"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      refute_enqueued(worker: IntegrationDispatcher)
    end

    test "does not enqueue for bindings of other monitors" do
      ws = workspace_fixture()
      monitor_a = monitor_fixture(workspace_id: ws.id)
      monitor_b = monitor_fixture(workspace_id: ws.id)
      integration = integration_fixture(workspace_id: ws.id, status: :active)

      _binding_on_a =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor_a,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-only-a"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor_b.id}

      Engine.dispatch_event(incident, "incident_opened")

      refute_enqueued(worker: IntegrationDispatcher)
    end

    test "skips disabled integrations even when a binding exists" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      integration = integration_fixture(workspace_id: ws.id, status: :disabled)

      _binding =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-disabled"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      refute_enqueued(worker: IntegrationDispatcher)
    end

    test "groups multiple bindings of the same integration into a single job" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      integration = integration_fixture(workspace_id: ws.id, status: :active)

      _b1 =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-111"
        )

      _b2 =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-222"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      jobs = all_enqueued(worker: IntegrationDispatcher)
      assert length(jobs) == 1
    end

    test "the enqueued job carries the targets in its args" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      integration = integration_fixture(workspace_id: ws.id, status: :active)

      _b1 =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-aaa"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      [job] = all_enqueued(worker: IntegrationDispatcher)
      assert [%{"type" => "campaign", "id" => "gads-aaa"}] = job.args["targets"]
    end

    test "enqueues one job per integration when bindings span multiple integrations" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)

      ig1 =
        integration_fixture(workspace_id: ws.id, provider: :google_ads, status: :active)

      ig2 = integration_fixture(workspace_id: ws.id, provider: :meta_ads, status: :active)

      _b1 =
        integration_binding_fixture(
          integration: ig1,
          monitor: monitor,
          event_type: "incident_opened",
          target_id: "gads-1"
        )

      _b2 =
        integration_binding_fixture(
          integration: ig2,
          monitor: monitor,
          event_type: "incident_opened",
          target_id: "meta-1"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      assert length(all_enqueued(worker: IntegrationDispatcher)) == 2
    end

    test "preserves the target_label in the serialized target payload" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      integration = integration_fixture(workspace_id: ws.id, status: :active)

      _binding =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-bf",
          target_label: "Black Friday"
        )

      incident = %{id: Ecto.UUID.generate(), monitor_id: monitor.id}

      Engine.dispatch_event(incident, "incident_opened")

      [job] = all_enqueued(worker: IntegrationDispatcher)
      assert [%{"label" => "Black Friday"}] = job.args["targets"]
    end
  end
end
