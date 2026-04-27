defmodule Holter.Delivery.NotificationChannelsTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery
  alias Holter.Delivery.{EmailChannel, MonitorNotification, NotificationChannel, WebhookChannel}
  alias Holter.Repo

  defp channel_attrs(workspace_id, overrides \\ %{}) do
    Map.merge(
      %{
        workspace_id: workspace_id,
        name: "Slack DevOps",
        type: :webhook,
        target: "https://hooks.slack.com/services/XYZ/123"
      },
      overrides
    )
  end

  defp channel_fixture(workspace_id, overrides \\ %{}) do
    {:ok, channel} = Delivery.create_channel(channel_attrs(workspace_id, overrides))
    channel
  end

  describe "list_channels/1" do
    test "excludes channels from other workspaces" do
      ws = workspace_fixture()
      other_ws = workspace_fixture()
      channel_fixture(ws.id)
      _other = channel_fixture(other_ws.id)

      assert [_] = Delivery.list_channels(ws.id)
    end

    test "returns the channel belonging to the workspace" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      channel_id = channel.id

      assert [%{id: ^channel_id}] = Delivery.list_channels(ws.id)
    end

    test "returns empty list when workspace has no channels" do
      ws = workspace_fixture()
      assert Delivery.list_channels(ws.id) == []
    end

    test "returns channels ordered by name" do
      ws = workspace_fixture()
      channel_fixture(ws.id, %{name: "Zulu", target: "https://example.com/z"})
      channel_fixture(ws.id, %{name: "Alpha", target: "https://example.com/a"})

      [first | _] = Delivery.list_channels(ws.id)
      assert first.name == "Alpha"
    end
  end

  describe "get_channel!/1" do
    test "returns channel when it exists" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      channel_id = channel.id
      assert %NotificationChannel{id: ^channel_id} = Delivery.get_channel!(channel.id)
    end

    test "raises when channel does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Delivery.get_channel!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_channel/1" do
    test "returns {:ok, channel} when channel exists" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      channel_id = channel.id
      assert {:ok, %{id: ^channel_id}} = Delivery.get_channel(channel.id)
    end

    test "returns {:error, :not_found} for unknown id" do
      assert {:error, :not_found} = Delivery.get_channel(Ecto.UUID.generate())
    end
  end

  describe "create_channel/1" do
    test "creates a channel with the given name" do
      ws = workspace_fixture()
      {:ok, channel} = Delivery.create_channel(channel_attrs(ws.id))
      assert channel.name == "Slack DevOps"
    end

    test "creates a channel with the given type" do
      ws = workspace_fixture()
      {:ok, channel} = Delivery.create_channel(channel_attrs(ws.id))
      assert channel.type == :webhook
    end

    test "returns changeset error when name is missing" do
      ws = workspace_fixture()
      {:error, changeset} = Delivery.create_channel(channel_attrs(ws.id, %{name: nil}))
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns changeset error when target URL is invalid for webhook" do
      ws = workspace_fixture()
      {:error, changeset} = Delivery.create_channel(channel_attrs(ws.id, %{target: "not-a-url"}))
      assert "must be a valid http or https URL" in errors_on(changeset).target
    end

    test "persists the URL on a webhook_channels row for webhook type" do
      ws = workspace_fixture()
      url = "https://hooks.example.com/abc"
      {:ok, channel} = Delivery.create_channel(channel_attrs(ws.id, %{target: url}))
      webhook = Repo.get_by!(WebhookChannel, notification_channel_id: channel.id)
      assert webhook.url == url
    end

    test "does not create an email_channels row for webhook type" do
      ws = workspace_fixture()
      {:ok, channel} = Delivery.create_channel(channel_attrs(ws.id))
      assert is_nil(Repo.get_by(EmailChannel, notification_channel_id: channel.id))
    end

    test "persists the address on an email_channels row for email type" do
      ws = workspace_fixture()
      address = "ops@example.com"

      {:ok, channel} =
        Delivery.create_channel(channel_attrs(ws.id, %{type: :email, target: address}))

      email = Repo.get_by!(EmailChannel, notification_channel_id: channel.id)
      assert email.address == address
    end

    test "does not create a webhook_channels row for email type" do
      ws = workspace_fixture()

      {:ok, channel} =
        Delivery.create_channel(channel_attrs(ws.id, %{type: :email, target: "ops@example.com"}))

      assert is_nil(Repo.get_by(WebhookChannel, notification_channel_id: channel.id))
    end
  end

  describe "update_channel/2" do
    test "updates channel name" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      {:ok, updated} = Delivery.update_channel(channel, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "returns changeset error for invalid type" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      {:error, changeset} = Delivery.update_channel(channel, %{type: :sms})
      assert "is invalid" in errors_on(changeset).type
    end
  end

  describe "regenerate_signing_token/1" do
    test "produces a new signing_token on the webhook subtype" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      original = channel.webhook_channel.signing_token

      {:ok, updated} = Delivery.regenerate_signing_token(channel)
      assert updated.webhook_channel.signing_token != original
    end

    test "persists the rotated token to the webhook_channels row" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)

      {:ok, updated} = Delivery.regenerate_signing_token(channel)
      reloaded = Repo.get_by!(WebhookChannel, notification_channel_id: channel.id)
      assert reloaded.signing_token == updated.webhook_channel.signing_token
    end

    test "returns {:error, :not_a_webhook_channel} for an email channel" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id, %{type: :email, target: "ops@example.com"})
      assert {:error, :not_a_webhook_channel} = Delivery.regenerate_signing_token(channel)
    end
  end

  describe "regenerate_anti_phishing_code/1" do
    test "produces a new anti_phishing_code on the email subtype" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id, %{type: :email, target: "ops@example.com"})
      original = channel.email_channel.anti_phishing_code

      {:ok, updated} = Delivery.regenerate_anti_phishing_code(channel)
      assert updated.email_channel.anti_phishing_code != original
    end

    test "persists the rotated code to the email_channels row" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id, %{type: :email, target: "ops@example.com"})

      {:ok, updated} = Delivery.regenerate_anti_phishing_code(channel)
      reloaded = Repo.get_by!(EmailChannel, notification_channel_id: channel.id)
      assert reloaded.anti_phishing_code == updated.email_channel.anti_phishing_code
    end

    test "returns {:error, :not_an_email_channel} for a webhook channel" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      assert {:error, :not_an_email_channel} = Delivery.regenerate_anti_phishing_code(channel)
    end
  end

  describe "delete_channel/1" do
    test "removes the channel from the database" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      Delivery.delete_channel(channel)
      assert {:error, :not_found} = Delivery.get_channel(channel.id)
    end

    test "returns {:ok, channel} on success" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      assert {:ok, _} = Delivery.delete_channel(channel)
    end

    test "cascades and removes the webhook_channels row" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      Delivery.delete_channel(channel)
      assert is_nil(Repo.get_by(WebhookChannel, notification_channel_id: channel.id))
    end

    test "cascades and removes the email_channels row" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id, %{type: :email, target: "ops@example.com"})
      Delivery.delete_channel(channel)
      assert is_nil(Repo.get_by(EmailChannel, notification_channel_id: channel.id))
    end
  end

  describe "link_monitor/2" do
    test "returns {:ok, _} when linking succeeds" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      assert {:ok, _} = Delivery.link_monitor(monitor.id, channel.id)
    end

    test "is idempotent when linking the same pair twice" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)
      assert {:ok, _} = Delivery.link_monitor(monitor.id, channel.id)
    end
  end

  describe "list_channels_for_monitor/1" do
    test "returns the linked channel" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)
      channel_id = channel.id
      assert [%{id: ^channel_id}] = Delivery.list_channels_for_monitor(monitor.id)
    end

    test "does not duplicate results when linked once" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)
      assert length(Delivery.list_channels_for_monitor(monitor.id)) == 1
    end

    test "excludes inactive links" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)

      Repo.update_all(
        MonitorNotification
        |> Ecto.Query.where(
          [mn],
          mn.monitor_id == ^monitor.id and mn.notification_channel_id == ^channel.id
        ),
        set: [is_active: false]
      )

      assert Delivery.list_channels_for_monitor(monitor.id) == []
    end
  end

  describe "unlink_monitor/2" do
    test "removes the linked channel" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)
      Delivery.unlink_monitor(monitor.id, channel.id)
      assert Delivery.list_channels_for_monitor(monitor.id) == []
    end

    test "returns :ok on success" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      Delivery.link_monitor(monitor.id, channel.id)
      assert :ok = Delivery.unlink_monitor(monitor.id, channel.id)
    end

    test "is safe when no link exists" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      assert :ok = Delivery.unlink_monitor(monitor.id, channel.id)
    end
  end
end
