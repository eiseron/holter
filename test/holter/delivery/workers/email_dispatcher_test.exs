defmodule Holter.Delivery.Workers.EmailDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  import Swoosh.TestAssertions

  alias Holter.Delivery.EmailChannels
  alias Holter.Delivery.Workers.EmailDispatcher

  defp from_address, do: Application.fetch_env!(:holter, :email)[:from_address]

  defp email_channel_fixture(workspace_id, opts \\ []) do
    {:ok, channel} =
      EmailChannels.create(%{
        workspace_id: workspace_id,
        name: Keyword.get(opts, :name, "Ops Email")
      })

    channel
  end

  defp add_verified_recipient(channel, email) do
    {:ok, recipient} = EmailChannels.add_recipient(channel.id, email)
    {:ok, _} = EmailChannels.verify_recipient(recipient.token)
    :ok
  end

  describe "perform/1 — incident notification" do
    test "delivers to: from_address with verified recipients in bcc" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)
      :ok = add_verified_recipient(channel, "ops@example.com")

      :ok =
        perform_job(EmailDispatcher, %{
          "email_channel_id" => channel.id,
          "workspace_id" => channel.workspace_id,
          "monitor_id" => monitor.id,
          "incident_id" => incident.id,
          "event" => "down"
        })

      assert_email_sent(to: [{"", from_address()}], bcc: [{"", "ops@example.com"}])
    end

    test "email subject indicates site is down" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id, url: "https://mysite.com")
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)
      :ok = add_verified_recipient(channel, "ops@example.com")

      perform_job(EmailDispatcher, %{
        "email_channel_id" => channel.id,
        "workspace_id" => channel.workspace_id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      assert_email_sent(subject: "Alert: https://mysite.com is down")
    end

    test "email body contains the channel's anti_phishing_code as a verification line" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)
      :ok = add_verified_recipient(channel, "ops@example.com")
      code = channel.anti_phishing_code

      perform_job(EmailDispatcher, %{
        "email_channel_id" => channel.id,
        "workspace_id" => channel.workspace_id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      assert_email_sent(fn email ->
        assert email.text_body =~ "Verification code: #{code}"
      end)
    end
  end

  describe "perform/1 — test ping" do
    test "sends a test email with verified recipients in bcc" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)
      :ok = add_verified_recipient(channel, "ops@example.com")

      :ok =
        perform_job(EmailDispatcher, %{
          "email_channel_id" => channel.id,
          "workspace_id" => channel.workspace_id,
          "test" => true
        })

      assert_email_sent(to: [{"", from_address()}], bcc: [{"", "ops@example.com"}])
    end

    test "all verified recipients land in bcc" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)
      :ok = add_verified_recipient(channel, "ops@example.com")
      :ok = add_verified_recipient(channel, "extra@example.com")

      :ok =
        perform_job(EmailDispatcher, %{
          "email_channel_id" => channel.id,
          "workspace_id" => channel.workspace_id,
          "test" => true
        })

      assert_email_sent(fn email ->
        assert Enum.sort(email.bcc) ==
                 Enum.sort([{"", "ops@example.com"}, {"", "extra@example.com"}])
      end)
    end

    test "unverified recipients are excluded from bcc" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)
      :ok = add_verified_recipient(channel, "ops@example.com")
      EmailChannels.add_recipient(channel.id, "pending@example.com")

      :ok =
        perform_job(EmailDispatcher, %{
          "email_channel_id" => channel.id,
          "workspace_id" => channel.workspace_id,
          "test" => true
        })

      assert_email_sent(fn email ->
        assert email.bcc == [{"", "ops@example.com"}]
      end)
    end
  end

  describe "perform/1 — verification gating" do
    test "a channel with no recipients cancels the incident email" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)

      result =
        perform_job(EmailDispatcher, %{
          "email_channel_id" => channel.id,
          "workspace_id" => channel.workspace_id,
          "monitor_id" => monitor.id,
          "incident_id" => incident.id,
          "event" => "down"
        })

      assert result == {:cancel, :no_verified_recipients}
      assert_no_email_sent()
    end

    test "a channel with no verified recipients cancels the test ping" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id)
      EmailChannels.add_recipient(channel.id, "pending@example.com")

      assert {:cancel, :no_verified_recipients} =
               perform_job(EmailDispatcher, %{
                 "email_channel_id" => channel.id,
                 "workspace_id" => channel.workspace_id,
                 "test" => true
               })

      assert_no_email_sent()
    end
  end
end
