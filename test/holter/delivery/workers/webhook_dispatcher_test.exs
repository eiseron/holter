defmodule Holter.Delivery.Workers.WebhookDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo
  import Mox

  alias Holter.Delivery
  alias Holter.Delivery.{ChannelLogs, HttpClientMock}
  alias Holter.Delivery.Workers.WebhookDispatcher

  defp webhook_channel_fixture(workspace_id) do
    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace_id,
        name: "Test Webhook",
        type: :webhook,
        target: "https://example.com/hook"
      })

    channel
  end

  describe "perform/1 — incident notification" do
    setup do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = webhook_channel_fixture(ws.id)

      %{monitor: monitor, incident: incident, channel: channel}
    end

    test "performs HTTP POST to channel target", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 200}} end)

      :ok =
        perform_job(WebhookDispatcher, %{
          "channel_id" => channel.id,
          "monitor_id" => monitor.id,
          "incident_id" => incident.id,
          "event" => "down"
        })

      verify!(HttpClientMock)
    end

    test "posts to the channel's target URL", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      expect(HttpClientMock, :post, fn url, _body, _headers ->
        assert url == "https://example.com/hook"
        {:ok, %{status: 200}}
      end)

      perform_job(WebhookDispatcher, %{
        "channel_id" => channel.id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      verify!(HttpClientMock)
    end

    test "posts JSON body with monitor_down event", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      expect(HttpClientMock, :post, fn _url, body, _headers ->
        {:ok, decoded} = Jason.decode(body)
        assert decoded["event"] == "monitor_down"
        {:ok, %{status: 200}}
      end)

      perform_job(WebhookDispatcher, %{
        "channel_id" => channel.id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      verify!(HttpClientMock)
    end
  end

  describe "perform/1 — test ping" do
    test "sends test payload to channel target" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      expect(HttpClientMock, :post, fn _url, body, _headers ->
        {:ok, decoded} = Jason.decode(body)
        assert decoded["event"] == "test_ping"
        {:ok, %{status: 200}}
      end)

      :ok = perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})
      verify!(HttpClientMock)
    end

    test "returns error when webhook returns non-2xx status" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 400}} end)

      assert {:error, _} =
               perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})
    end

    test "creates a success log when test ping returns 2xx" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 200}} end)

      perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})

      %{logs: [log]} = ChannelLogs.list_channel_logs(channel, %{})
      assert log.status == :success
    end

    test "test ping log has event_type 'test' and no monitor or incident refs" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 200}} end)

      perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})

      %{logs: [log]} = ChannelLogs.list_channel_logs(channel, %{})
      assert log.event_type == "test" and is_nil(log.monitor_id) and is_nil(log.incident_id)
    end

    test "creates a failed log when test ping returns non-2xx" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 400}} end)

      perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})

      %{logs: [log]} = ChannelLogs.list_channel_logs(channel, %{})
      assert log.status == :failed
    end

    test "failed test ping log includes HTTP status in error_message" do
      ws = workspace_fixture()
      channel = webhook_channel_fixture(ws.id)

      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 400}} end)

      perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})

      %{logs: [log]} = ChannelLogs.list_channel_logs(channel, %{})
      assert log.error_message =~ "400"
    end
  end

  describe "perform/1 — incident notification log creation" do
    setup do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = webhook_channel_fixture(ws.id)
      %{monitor: monitor, incident: incident, channel: channel}
    end

    test "creates a success log on successful dispatch", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 200}} end)

      perform_job(WebhookDispatcher, %{
        "channel_id" => channel.id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      %{logs: [log]} = ChannelLogs.list_channel_logs(channel, %{})
      assert log.status == :success
    end

    test "incident log records event_type, monitor_id, and incident_id", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 200}} end)

      perform_job(WebhookDispatcher, %{
        "channel_id" => channel.id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      %{logs: [log]} = ChannelLogs.list_channel_logs(channel, %{})

      assert log.event_type == "down" and log.monitor_id == monitor.id and
               log.incident_id == incident.id
    end

    test "creates a failed log when HTTP call returns an error", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      stub(HttpClientMock, :post, fn _url, _body, _headers ->
        {:error, :connection_refused}
      end)

      perform_job(WebhookDispatcher, %{
        "channel_id" => channel.id,
        "monitor_id" => monitor.id,
        "incident_id" => incident.id,
        "event" => "down"
      })

      %{logs: [log]} = ChannelLogs.list_channel_logs(channel, %{})
      assert log.status == :failed and log.error_message =~ "connection_refused"
    end
  end
end
