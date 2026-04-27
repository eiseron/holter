defmodule Holter.Delivery.Engine.ChannelFormatterTest do
  use ExUnit.Case, async: true

  alias Holter.Delivery.EmailChannel
  alias Holter.Delivery.Engine.ChannelFormatter

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

  describe "format_payload/2 — :email" do
    test "subject contains the monitor URL for a down event" do
      {subject, _body} = ChannelFormatter.format_payload(down_payload(), :email)
      assert String.contains?(subject, "https://example.com")
    end

    test "subject indicates alert for monitor_down event" do
      {subject, _body} = ChannelFormatter.format_payload(down_payload(), :email)
      assert String.contains?(subject, "Alert")
    end

    test "subject indicates resolved for monitor_up event" do
      payload = %{down_payload() | event: "monitor_up"}
      {subject, _body} = ChannelFormatter.format_payload(payload, :email)
      assert String.contains?(subject, "Resolved")
    end

    test "body contains the event name" do
      {_subject, body} = ChannelFormatter.format_payload(down_payload(), :email)
      assert String.contains?(body, "monitor_down")
    end

    test "body contains the monitor URL" do
      {_subject, body} = ChannelFormatter.format_payload(down_payload(), :email)
      assert String.contains?(body, "https://example.com")
    end

    test "body contains the root cause" do
      {_subject, body} = ChannelFormatter.format_payload(down_payload(), :email)
      assert String.contains?(body, "Server 500")
    end
  end

  describe "append_anti_phishing_footer/2" do
    test "appends a 'Verification code:' line referencing the channel's code" do
      footer_body =
        ChannelFormatter.append_anti_phishing_footer(
          "incident details",
          %EmailChannel{anti_phishing_code: "ABCD-EFGH"}
        )

      assert footer_body =~ "Verification code: ABCD-EFGH"
    end

    test "preserves the original body as a prefix" do
      original = "incident details"

      result =
        ChannelFormatter.append_anti_phishing_footer(original, %EmailChannel{
          anti_phishing_code: "ABCD-EFGH"
        })

      assert String.starts_with?(result, original)
    end

    test "warns the recipient not to trust messages missing the code" do
      result =
        ChannelFormatter.append_anti_phishing_footer("body", %EmailChannel{
          anti_phishing_code: "ABCD-EFGH"
        })

      assert result =~ "do not trust"
    end

    test "warns the recipient not to forward the email to untrusted parties" do
      result =
        ChannelFormatter.append_anti_phishing_footer("body", %EmailChannel{
          anti_phishing_code: "ABCD-EFGH"
        })

      assert result =~ "Do not forward this email"
    end

    test "returns the body untouched when the channel has no anti_phishing_code" do
      assert ChannelFormatter.append_anti_phishing_footer("body", %EmailChannel{
               anti_phishing_code: nil
             }) == "body"
    end

    test "returns the body untouched when the second argument is not an EmailChannel" do
      assert ChannelFormatter.append_anti_phishing_footer("body", nil) == "body"
    end
  end
end
