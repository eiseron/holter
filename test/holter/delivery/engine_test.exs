defmodule Holter.Delivery.EngineTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Delivery
  alias Holter.Delivery.Engine
  alias Holter.Delivery.Workers.{EmailDispatcher, WebhookDispatcher}

  setup do
    Phoenix.PubSub.subscribe(Holter.PubSub, "delivery:notifications")
    :ok
  end

  defp webhook_channel_fixture(workspace_id) do
    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace_id,
        name: "Webhook",
        type: :webhook,
        target: "https://example.com/hook"
      })

    channel
  end

  defp email_channel_fixture(workspace_id) do
    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace_id,
        name: "Email",
        type: :email,
        target: "ops@example.com"
      })

    channel
  end

  describe "dispatch_incident/3" do
    test "enqueues WebhookDispatcher job for a webhook channel" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = webhook_channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)

      Engine.dispatch_incident(monitor.id, incident.id, :down)

      assert_enqueued(
        worker: WebhookDispatcher,
        args: %{"event" => "down", "channel_id" => channel.id}
      )
    end

    test "enqueues EmailDispatcher job for an email channel" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)

      Engine.dispatch_incident(monitor.id, incident.id, :down)

      assert_enqueued(
        worker: EmailDispatcher,
        args: %{"event" => "down", "channel_id" => channel.id}
      )
    end

    test "enqueues a job for each linked channel" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      webhook = webhook_channel_fixture(ws.id)
      email = email_channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, webhook.id)
      Delivery.link_monitor(monitor.id, email.id)

      Engine.dispatch_incident(monitor.id, incident.id, :down)

      assert length(all_enqueued(queue: :notifications)) == 2
    end

    test "does not enqueue jobs when monitor has no linked channels" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)

      Engine.dispatch_incident(monitor.id, incident.id, :down)

      assert all_enqueued(queue: :notifications) == []
    end

    test "broadcasts notification_dispatched on delivery:notifications" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      monitor_id = monitor.id
      incident_id = incident.id

      Engine.dispatch_incident(monitor.id, incident.id, :down)

      assert_receive {:notification_dispatched,
                      %{monitor_id: ^monitor_id, incident_id: ^incident_id, event: :down}}
    end

    test "enqueues job with :up event for resolved incident" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = webhook_channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)

      Engine.dispatch_incident(monitor.id, incident.id, :up)

      assert_enqueued(worker: WebhookDispatcher, args: %{"event" => "up"})
    end
  end

  describe "dispatch_test/1" do
    test "enqueues a WebhookDispatcher test job for a webhook channel" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      Engine.dispatch_test(channel.id)

      assert_enqueued(
        worker: WebhookDispatcher,
        args: %{"test" => true, "channel_id" => channel.id}
      )
    end

    test "enqueues an EmailDispatcher test job for an email channel" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)

      Engine.dispatch_test(channel.id)

      assert_enqueued(
        worker: EmailDispatcher,
        args: %{"test" => true, "channel_id" => channel.id}
      )
    end

    test "broadcasts test_dispatched on delivery:notifications" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)
      channel_id = channel.id

      Engine.dispatch_test(channel.id)

      assert_receive {:test_dispatched, %{channel_id: ^channel_id}}
    end
  end
end
