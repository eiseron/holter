defmodule Holter.Delivery.MonitorNotificationTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.MonitorNotification

  defp valid_attrs(monitor_id, channel_id, overrides \\ %{}) do
    Map.merge(%{monitor_id: monitor_id, notification_channel_id: channel_id}, overrides)
  end

  defp channel_fixture(workspace_id) do
    {:ok, channel} =
      Holter.Delivery.NotificationChannel.changeset(
        %Holter.Delivery.NotificationChannel{},
        %{
          workspace_id: workspace_id,
          name: "Test Webhook",
          type: :webhook,
          target: "https://example.com/hook"
        }
      )
      |> Holter.Repo.insert()

    channel
  end

  describe "changeset/2 — required fields" do
    test "is valid with monitor_id and notification_channel_id" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      changeset = MonitorNotification.changeset(%MonitorNotification{}, valid_attrs(monitor.id, channel.id))
      assert changeset.valid?
    end

    test "is invalid without monitor_id" do
      ws = workspace_fixture()
      channel = channel_fixture(ws.id)
      changeset = MonitorNotification.changeset(%MonitorNotification{}, valid_attrs(nil, channel.id))
      assert "can't be blank" in errors_on(changeset).monitor_id
    end

    test "is invalid without notification_channel_id" do
      monitor = monitor_fixture()
      changeset = MonitorNotification.changeset(%MonitorNotification{}, valid_attrs(monitor.id, nil))
      assert "can't be blank" in errors_on(changeset).notification_channel_id
    end
  end

  describe "changeset/2 — is_active default" do
    test "defaults is_active to true" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      changeset = MonitorNotification.changeset(%MonitorNotification{}, valid_attrs(monitor.id, channel.id))
      assert get_field(changeset, :is_active) == true
    end

    test "accepts is_active false" do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      channel = channel_fixture(ws.id)
      changeset = MonitorNotification.changeset(%MonitorNotification{}, valid_attrs(monitor.id, channel.id, %{is_active: false}))
      assert get_field(changeset, :is_active) == false
    end
  end
end
