defmodule Holter.Delivery.Engine.PayloadBuilderTest do
  use ExUnit.Case, async: true

  alias Holter.Delivery.Engine.PayloadBuilder

  @now ~U[2026-04-20 10:00:00Z]

  defp monitor_stub do
    %{id: "mon-1", url: "https://example.com", health_status: :down}
  end

  defp incident_stub do
    %{
      id: "inc-1",
      type: :downtime,
      started_at: ~U[2026-04-20 09:00:00Z],
      resolved_at: nil,
      duration_seconds: nil,
      root_cause: "Server returned 500"
    }
  end

  describe "build_incident_payload/4 — event naming" do
    test "sets event to monitor_down when event is :down" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.event == "monitor_down"
    end

    test "sets event to monitor_up when event is :up" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :up,
          now: @now
        })

      assert payload.event == "monitor_up"
    end
  end

  describe "build_incident_payload/4 — version and timestamp" do
    test "sets version to 1.0" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.version == "1.0"
    end

    test "sets timestamp to ISO 8601 of the given now" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.timestamp == "2026-04-20T10:00:00Z"
    end
  end

  describe "build_incident_payload/4 — monitor data" do
    test "includes monitor id" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.monitor.id == "mon-1"
    end

    test "includes monitor url" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.monitor.url == "https://example.com"
    end

    test "includes monitor health_status" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.monitor.health_status == :down
    end
  end

  describe "build_incident_payload/4 — incident data" do
    test "includes incident id" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.incident.id == "inc-1"
    end

    test "includes incident type" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.incident.type == :downtime
    end

    test "includes incident started_at as ISO 8601 string" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.incident.started_at == "2026-04-20T09:00:00Z"
    end

    test "sets resolved_at to nil for an open incident" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert is_nil(payload.incident.resolved_at)
    end

    test "sets resolved_at as ISO 8601 when present" do
      incident = %{incident_stub() | resolved_at: ~U[2026-04-20 09:30:00Z]}

      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident, %{event: :up, now: @now})

      assert payload.incident.resolved_at == "2026-04-20T09:30:00Z"
    end

    test "includes root_cause" do
      payload =
        PayloadBuilder.build_incident_payload(monitor_stub(), incident_stub(), %{
          event: :down,
          now: @now
        })

      assert payload.incident.root_cause == "Server returned 500"
    end
  end

  describe "build_test_payload/3" do
    test "sets event to test_ping" do
      channel = %{id: "ch-1", name: "Slack DevOps"}
      payload = PayloadBuilder.build_test_payload(channel, :webhook, @now)
      assert payload.event == "test_ping"
    end

    test "includes channel id" do
      channel = %{id: "ch-1", name: "Slack DevOps"}
      payload = PayloadBuilder.build_test_payload(channel, :webhook, @now)
      assert payload.channel.id == "ch-1"
    end

    test "includes channel name" do
      channel = %{id: "ch-1", name: "Slack DevOps"}
      payload = PayloadBuilder.build_test_payload(channel, :webhook, @now)
      assert payload.channel.name == "Slack DevOps"
    end

    test "sets version to 1.0" do
      channel = %{id: "ch-1", name: "Slack DevOps"}
      payload = PayloadBuilder.build_test_payload(channel, :webhook, @now)
      assert payload.version == "1.0"
    end
  end
end
