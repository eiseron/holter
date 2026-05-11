defmodule Holter.Delivery.Engine.ChannelFormatterTest do
  use ExUnit.Case, async: true

  alias Holter.Delivery.Engine.ChannelFormatter
  alias Holter.Delivery.Models.EmailChannel

  defp down_payload do
    %{
      version: "1.0",
      event: "monitor_down",
      timestamp: "2026-04-20T10:00:00Z",
      monitor: %{id: "mon-1", url: "https://example.com", health_status: :down},
      incident: %{
        id: "inc-1",
        type: :downtime,
        started_at: "2026-04-20T09:00:00Z",
        resolved_at: nil,
        duration_seconds: nil,
        root_cause: "Server 500"
      }
    }
  end

  defp up_payload, do: %{down_payload() | event: "monitor_up"}

  defp test_payload do
    %{
      version: "1.0",
      event: "test_ping",
      timestamp: "2026-04-20T10:00:00Z",
      channel: %{id: "ch-1", name: "Ops Email"}
    }
  end

  defp channel_with_code, do: %EmailChannel{anti_phishing_code: "ABCD-EFGH"}

  describe "format_payload/2 — :webhook" do
    test "returns valid JSON as first element" do
      {json, _headers} = ChannelFormatter.format_payload(down_payload(), :webhook)
      assert {:ok, _} = Jason.decode(json)
    end

    test "returns content-type application/json header" do
      {_json, headers} = ChannelFormatter.format_payload(down_payload(), :webhook)
      assert {"content-type", "application/json"} in headers
    end

    test "JSON body contains event field" do
      {json, _} = ChannelFormatter.format_payload(down_payload(), :webhook)
      {:ok, decoded} = Jason.decode(json)
      assert decoded["event"] == "monitor_down"
    end
  end

  describe "format_email/2 — subject" do
    test "embeds the monitor URL for a down event" do
      assert ChannelFormatter.format_email(down_payload()).subject =~ "https://example.com"
    end

    test "uses the alert verbiage for a down event" do
      assert ChannelFormatter.format_email(down_payload()).subject =~ "Alert"
    end

    test "uses the resolved verbiage for an up event" do
      assert ChannelFormatter.format_email(up_payload()).subject =~ "Resolved"
    end

    test "names the channel for a test ping" do
      assert ChannelFormatter.format_email(test_payload()).subject =~ "Ops Email"
    end
  end

  describe "format_email/2 — text body" do
    test "lists the event name for a down event" do
      assert ChannelFormatter.format_email(down_payload()).text =~ "monitor_down"
    end

    test "lists the monitor URL for a down event" do
      assert ChannelFormatter.format_email(down_payload()).text =~ "https://example.com"
    end

    test "includes the incident root cause when one is set" do
      assert ChannelFormatter.format_email(down_payload()).text =~ "Server 500"
    end

    test "frames the body with the shared Holter wordmark header" do
      assert String.starts_with?(ChannelFormatter.format_email(down_payload()).text, "Holter")
    end

    test "appends the verification code when the channel carries one" do
      result = ChannelFormatter.format_email(down_payload(), channel_with_code()).text

      assert result =~ "Verification code: ABCD-EFGH"
    end

    test "warns the recipient not to trust messages missing the verification code" do
      result = ChannelFormatter.format_email(down_payload(), channel_with_code()).text

      assert result =~ "do not trust"
    end

    test "omits the anti-phishing footer when the channel has no code" do
      result =
        ChannelFormatter.format_email(down_payload(), %EmailChannel{anti_phishing_code: nil}).text

      refute result =~ "Verification code"
    end
  end

  describe "format_email/2 — html body" do
    test "embeds the monitor URL for a down event" do
      assert ChannelFormatter.format_email(down_payload()).html =~ "https://example.com"
    end

    test "includes the down heading for a down event" do
      assert ChannelFormatter.format_email(down_payload()).html =~ "Monitor down"
    end

    test "includes the recovered heading for an up event" do
      assert ChannelFormatter.format_email(up_payload()).html =~ "Monitor recovered"
    end

    test "includes the test notification heading for a test ping" do
      assert ChannelFormatter.format_email(test_payload()).html =~ "Test notification"
    end

    test "renders the verification code inside the html footer when the channel carries one" do
      assert ChannelFormatter.format_email(down_payload(), channel_with_code()).html =~
               "ABCD-EFGH"
    end

    test "omits the anti-phishing block from html when the channel has no code" do
      result =
        ChannelFormatter.format_email(down_payload(), %EmailChannel{anti_phishing_code: nil}).html

      refute result =~ "Verification code"
    end

    test "produces a complete HTML document with a DOCTYPE" do
      assert String.starts_with?(ChannelFormatter.format_email(down_payload()).html, "<!DOCTYPE")
    end
  end
end
