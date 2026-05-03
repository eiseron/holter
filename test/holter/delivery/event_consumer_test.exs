defmodule Holter.Delivery.EventConsumerTest do
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias Holter.Delivery.WebhookChannels
  alias Holter.Delivery.Workers.WebhookDispatcher

  setup do
    {:ok, pid} = start_supervised(Holter.Delivery.EventConsumer)
    Sandbox.allow(Holter.Repo, self(), pid)
    :ok
  end

  defp webhook_channel_fixture(workspace_id) do
    {:ok, channel} =
      WebhookChannels.create(%{
        workspace_id: workspace_id,
        name: "Test Webhook",
        url: "https://example.com/hook"
      })

    channel
  end

  describe "incident_opened event" do
    test "enqueues WebhookDispatcher job when an incident is opened for a linked monitor" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = webhook_channel_fixture(ws.id)
      WebhookChannels.link_monitor(monitor.id, channel.id)

      incident = incident_fixture(monitor_id: monitor.id)

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:incident_opened, incident}
      )

      Process.sleep(50)

      assert_enqueued(
        worker: WebhookDispatcher,
        args: %{"event" => "down", "monitor_id" => monitor.id, "incident_id" => incident.id}
      )
    end

    test "does not enqueue jobs when monitor has no linked channels" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:incident_opened, incident}
      )

      Process.sleep(50)

      assert all_enqueued(queue: :notifications) == []
    end
  end

  describe "incident_resolved event" do
    test "enqueues a :up job when an incident is resolved" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = webhook_channel_fixture(ws.id)
      WebhookChannels.link_monitor(monitor.id, channel.id)

      incident = incident_fixture(monitor_id: monitor.id)

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:incidents",
        {:incident_resolved, incident}
      )

      Process.sleep(50)

      assert_enqueued(worker: WebhookDispatcher, args: %{"event" => "up"})
    end
  end
end
