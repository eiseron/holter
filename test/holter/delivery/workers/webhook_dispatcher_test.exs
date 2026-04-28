defmodule Holter.Delivery.Workers.WebhookDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo
  import Mox

  alias Holter.Delivery
  alias Holter.Delivery.HttpClientMock
  alias Holter.Delivery.WebhookSignature
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

  describe "perform/1 — webhook signature" do
    setup do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = webhook_channel_fixture(ws.id)

      %{monitor: monitor, incident: incident, channel: channel}
    end

    test "POST headers include x-holter-signature when the channel has a signing_token", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      expect(HttpClientMock, :post, fn _url, _body, headers ->
        assert List.keyfind(headers, WebhookSignature.header_name(), 0)
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

    test "the signature value follows the t=<unix>,v1=<hex> format", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      expect(HttpClientMock, :post, fn _url, _body, headers ->
        {_, value} = List.keyfind(headers, WebhookSignature.header_name(), 0)
        assert value =~ ~r/^t=\d+,v1=[0-9a-f]{64}$/
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

    test "the signature verifies against the channel's signing_token and the body", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      token = channel.webhook_channel.signing_token

      expect(HttpClientMock, :post, fn _url, body, headers ->
        {_, value} = List.keyfind(headers, WebhookSignature.header_name(), 0)
        ["t=" <> unix, "v1=" <> received_hex] = String.split(value, ",")

        expected_hex =
          :crypto.mac(:hmac, :sha256, token, "#{unix}.#{body}")
          |> Base.encode16(case: :lower)

        assert received_hex == expected_hex
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
  end

  describe "perform/1 — outbound posture" do
    setup do
      ws = workspace_fixture()
      monitor = monitor_fixture(workspace_id: ws.id)
      incident = incident_fixture(monitor_id: monitor.id)
      channel = webhook_channel_fixture(ws.id)

      %{monitor: monitor, incident: incident, channel: channel}
    end

    test "redirect responses are not auto-followed (test ping surfaces non-2xx as error)", %{
      channel: channel
    } do
      expect(HttpClientMock, :post, 1, fn _url, _body, _headers ->
        {:ok, %{status: 301}}
      end)

      assert {:error, _} =
               perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})

      verify!(HttpClientMock)
    end

    test "5xx responses surface as errors so Oban can retry", %{channel: channel} do
      stub(HttpClientMock, :post, fn _url, _body, _headers -> {:ok, %{status: 503}} end)

      assert {:error, _} =
               perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})
    end

    test "transport-level timeouts surface as errors", %{channel: channel} do
      stub(HttpClientMock, :post, fn _url, _body, _headers ->
        {:error, %RuntimeError{message: "timeout"}}
      end)

      assert {:error, _} =
               perform_job(WebhookDispatcher, %{"channel_id" => channel.id, "test" => true})
    end

    test "incident dispatch swallows transport errors silently to avoid retry storms", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      stub(HttpClientMock, :post, fn _url, _body, _headers ->
        {:error, %RuntimeError{message: "boom"}}
      end)

      assert :ok =
               perform_job(WebhookDispatcher, %{
                 "channel_id" => channel.id,
                 "monitor_id" => monitor.id,
                 "incident_id" => incident.id,
                 "event" => "down"
               })
    end

    test "signature uses the channel's most recent signing token after rotation", %{
      monitor: monitor,
      incident: incident,
      channel: channel
    } do
      original_token = channel.webhook_channel.signing_token
      {:ok, rotated} = Delivery.regenerate_signing_token(channel)
      new_token = rotated.webhook_channel.signing_token

      assert original_token != new_token

      expect(HttpClientMock, :post, fn _url, body, headers ->
        {_, value} = List.keyfind(headers, WebhookSignature.header_name(), 0)
        ["t=" <> unix, "v1=" <> received_hex] = String.split(value, ",")

        expected_with_new = WebhookSignature.compute_hmac(new_token, "#{unix}.#{body}")
        expected_with_old = WebhookSignature.compute_hmac(original_token, "#{unix}.#{body}")

        assert received_hex == expected_with_new
        refute received_hex == expected_with_old

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
end
