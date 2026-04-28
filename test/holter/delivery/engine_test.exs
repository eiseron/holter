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

  defp email_channel_fixture(workspace_id, opts \\ []) do
    verified? = Keyword.get(opts, :verified, true)

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace_id,
        name: "Email",
        type: :email,
        target: "ops@example.com"
      })

    if verified?, do: mark_channel_verified(channel), else: channel
  end

  defp mark_channel_verified(channel) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    channel.email_channel
    |> Ecto.Changeset.change(verified_at: now)
    |> Holter.Repo.update!()

    Delivery.get_channel!(channel.id)
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

    test "returns {:error, :no_verified_recipients} for an email channel with no verified addresses" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id, verified: false)

      assert {:error, :no_verified_recipients} = Engine.dispatch_test(channel.id)
    end

    test "does not enqueue a job when an email channel has no verified addresses" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id, verified: false)

      Engine.dispatch_test(channel.id)

      assert all_enqueued(queue: :notifications) == []
    end

    test "enqueues a job for an email channel whose primary is unverified but has a verified CC" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id, verified: false)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "cc@example.com")
      Delivery.verify_recipient(recipient.token)

      Engine.dispatch_test(channel.id)

      assert_enqueued(worker: EmailDispatcher, args: %{"test" => true})
    end
  end

  describe "dispatch_test/1 — per-channel cooldown" do
    test "first dispatch records last_test_dispatched_at on the channel" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      Engine.dispatch_test(channel.id)

      reloaded = Holter.Repo.get!(Holter.Delivery.NotificationChannel, channel.id)
      assert %DateTime{} = reloaded.last_test_dispatched_at
    end

    test "second dispatch within the cooldown returns :test_dispatch_rate_limited" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      Engine.dispatch_test(channel.id)

      assert {:error, :test_dispatch_rate_limited} = Engine.dispatch_test(channel.id)
    end

    test "rate-limited dispatch enqueues no additional Oban job" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      Engine.dispatch_test(channel.id)
      Engine.dispatch_test(channel.id)
      Engine.dispatch_test(channel.id)

      assert length(all_enqueued(queue: :notifications)) == 1
    end

    test "rate-limited dispatch does not broadcast test_dispatched" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)
      channel_id = channel.id

      Engine.dispatch_test(channel.id)
      assert_receive {:test_dispatched, %{channel_id: ^channel_id}}

      Engine.dispatch_test(channel.id)
      refute_receive {:test_dispatched, _}, 100
    end

    test "dispatch is allowed again once the cooldown has elapsed" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      Engine.dispatch_test(channel.id)
      backdate_test_dispatch(channel.id, Engine.test_dispatch_cooldown() + 1)

      assert {:ok, %Oban.Job{}} = Engine.dispatch_test(channel.id)
    end

    test "cooldown is tracked per channel — pinging A does not block B" do
      ws = workspace_fixture()
      channel_a = webhook_channel_fixture(ws.id)

      {:ok, channel_b} =
        Delivery.create_channel(%{
          workspace_id: ws.id,
          name: "Other Webhook",
          type: :webhook,
          target: "https://example.com/other"
        })

      Engine.dispatch_test(channel_a.id)

      assert {:ok, %Oban.Job{}} = Engine.dispatch_test(channel_b.id)
    end
  end

  defp backdate_test_dispatch(channel_id, seconds_ago) do
    past = DateTime.utc_now() |> DateTime.add(-seconds_ago, :second) |> DateTime.truncate(:second)

    Holter.Delivery.NotificationChannel
    |> Holter.Repo.get!(channel_id)
    |> Ecto.Changeset.change(last_test_dispatched_at: past)
    |> Holter.Repo.update!()
  end
end
