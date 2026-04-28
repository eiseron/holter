defmodule Holter.Delivery.Workers.EmailDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  import Swoosh.TestAssertions

  alias Holter.Delivery
  alias Holter.Delivery.Workers.EmailDispatcher
  alias Holter.Repo

  defp email_channel_fixture(workspace_id, opts \\ []) do
    verified? = Keyword.get(opts, :verified, true)

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace_id,
        name: "Ops Email",
        type: :email,
        target: Keyword.get(opts, :target, "ops@example.com")
      })

    if verified?, do: mark_verified(channel), else: channel
  end

  defp mark_verified(channel) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    channel.email_channel
    |> Ecto.Changeset.change(verified_at: now)
    |> Repo.update!()

    Delivery.get_channel!(channel.id)
  end

  defp run_dispatch_with_unverified_primary_and_one_verified_cc(ws) do
    monitor = monitor_fixture(workspace_id: ws.id)
    incident = incident_fixture(monitor_id: monitor.id)
    channel = email_channel_fixture(ws.id, verified: false)
    {:ok, recipient} = Delivery.add_recipient(channel.id, "cc@example.com")
    Delivery.verify_recipient(recipient.token)

    :ok =
      perform_job(EmailDispatcher, %{
        "channel_id" => channel.id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })
  end

  defp run_dispatch_with_verified_primary_and_one_verified_cc(ws) do
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

    test "email body contains the channel's anti_phishing_code as a verification line" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id)
      code = channel.email_channel.anti_phishing_code

      perform_job(EmailDispatcher, %{
        "channel_id" => channel.id,
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

  describe "perform/1 — verification gating on the primary target" do
    test "an unverified primary is dropped: incident email is not sent at all when no verified addresses exist" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id, verified: false)

      result =
        perform_job(EmailDispatcher, %{
          "channel_id" => channel.id,
          "monitor_id" => monitor.id,
          "incident_id" => incident.id,
          "event" => "down"
        })

      assert result == {:cancel, :no_verified_recipients}
      assert_no_email_sent()
    end

    test "an unverified primary is dropped: a test ping with no verified addresses cancels" do
      ws = workspace_fixture()
      channel = email_channel_fixture(ws.id, verified: false)

      assert {:cancel, :no_verified_recipients} =
               perform_job(EmailDispatcher, %{"channel_id" => channel.id, "test" => true})

      assert_no_email_sent()
    end

    test "a verified CC becomes to: when the primary is unverified" do
      ws = workspace_fixture()
      run_dispatch_with_unverified_primary_and_one_verified_cc(ws)

      assert_email_sent(to: "cc@example.com")
    end

    test "no CCs are added when the only address is the promoted primary" do
      ws = workspace_fixture()
      run_dispatch_with_unverified_primary_and_one_verified_cc(ws)

      assert_email_sent(fn email -> email.cc == [] end)
    end

    test "the primary remains in to: when verified, with verified CCs in cc:" do
      ws = workspace_fixture()
      run_dispatch_with_verified_primary_and_one_verified_cc(ws)

      assert_email_sent(to: "ops@example.com")
    end

    test "verified CCs land in cc: alongside a verified primary" do
      ws = workspace_fixture()
      run_dispatch_with_verified_primary_and_one_verified_cc(ws)

      assert_email_sent(cc: [{"", "cc@example.com"}])
    end

    test "an unverified primary plus only an unverified CC sends nothing" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = email_channel_fixture(ws.id, verified: false)
      Delivery.add_recipient(channel.id, "pending@example.com")

      assert {:cancel, :no_verified_recipients} =
               perform_job(EmailDispatcher, %{
                 "channel_id" => channel.id,
                 "monitor_id" => monitor.id,
                 "incident_id" => incident.id,
                 "event" => "down"
               })

      assert_no_email_sent()
    end
  end
end
