defmodule Holter.Delivery.Workers.EmailDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  import Swoosh.TestAssertions

  alias Holter.Delivery
  alias Holter.Delivery.Workers.EmailDispatcher

  defp email_channel_fixture(workspace_id) do
    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace_id,
        name: "Ops Email",
        type: :email,
        target: "ops@example.com"
      })

    channel
  end

  describe "perform/1 — incident notification" do
    test "sends an email to the channel target" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)

      :ok =
        perform_job(EmailDispatcher, %{
          "channel_id" => channel.id,
          "monitor_id" => monitor.id,
          "incident_id" => incident.id,
          "event" => "down"
        })

      assert_email_sent(to: "ops@example.com")
    end

    test "email subject indicates site is down" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id, url: "https://mysite.com")
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)

      perform_job(EmailDispatcher, %{
        "channel_id" => channel.id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      assert_email_sent(subject: "Alert: https://mysite.com is down")
    end
  end

  describe "perform/1 — test ping" do
    test "sends a test email to the channel target" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)

      :ok = perform_job(EmailDispatcher, %{"channel_id" => channel.id, "test" => true})
      assert_email_sent(to: "ops@example.com")
    end

    test "includes verified CC recipients in test email" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "cc@example.com")
      Delivery.verify_recipient(recipient.token)

      :ok = perform_job(EmailDispatcher, %{"channel_id" => channel.id, "test" => true})

      assert_email_sent(cc: [{"", "cc@example.com"}])
    end

    test "does not include unverified CC recipients in test email" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)
      Delivery.add_recipient(channel.id, "pending@example.com")

      :ok = perform_job(EmailDispatcher, %{"channel_id" => channel.id, "test" => true})

      assert_email_sent(fn email -> email.cc == [] end)
    end
  end

  describe "perform/1 — incident notification with CC" do
    test "includes verified CC recipients in incident email" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "cc@example.com")
      Delivery.verify_recipient(recipient.token)

      :ok =
        perform_job(EmailDispatcher, %{
          "channel_id" => channel.id,
          "monitor_id" => monitor.id,
          "incident_id" => incident.id,
          "event" => "down"
        })

      assert_email_sent(cc: [{"", "cc@example.com"}])
    end
  end
end
