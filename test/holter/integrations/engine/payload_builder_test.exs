defmodule Holter.Integrations.Engine.PayloadBuilderTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Engine.PayloadBuilder

  describe "build_dispatch_payload/3" do
    test "includes integration and incident ids" do
      integration = %{
        id: "ig-1",
        provider: :google_ads,
        workspace_id: "ws-1",
        settings: %{"campaign_ids" => ["c1"]},
        subscribed_events: ["incident_opened"]
      }

      incident = %{id: "inc-1", monitor_id: "mon-1"}

      payload = PayloadBuilder.build_dispatch_payload(integration, "incident_opened", incident)

      assert payload.integration_id == "ig-1"
    end

    test "includes the event name" do
      integration = %{
        id: "ig-1",
        provider: :slack,
        workspace_id: "ws-1",
        settings: %{},
        subscribed_events: ["incident_opened"]
      }

      incident = %{id: "inc-1", monitor_id: "mon-1"}

      payload = PayloadBuilder.build_dispatch_payload(integration, "incident_opened", incident)

      assert payload.event == "incident_opened"
    end

    test "includes provider settings" do
      integration = %{
        id: "ig-1",
        provider: :google_ads,
        workspace_id: "ws-1",
        settings: %{"campaign_ids" => ["c1", "c2"]},
        subscribed_events: ["incident_opened"]
      }

      incident = %{id: "inc-1", monitor_id: "mon-1"}

      payload = PayloadBuilder.build_dispatch_payload(integration, "incident_opened", incident)

      assert payload.settings == %{"campaign_ids" => ["c1", "c2"]}
    end

    test "defaults settings to empty map when nil" do
      integration = %{
        id: "ig-1",
        provider: :slack,
        workspace_id: "ws-1",
        settings: nil,
        subscribed_events: []
      }

      incident = %{id: "inc-1", monitor_id: "mon-1"}

      payload = PayloadBuilder.build_dispatch_payload(integration, "incident_resolved", incident)

      assert payload.settings == %{}
    end
  end

  describe "build_redacted_payload/1" do
    test "keeps the event field" do
      payload = %{
        integration_id: "ig-1",
        provider: :google_ads,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: %{}
      }

      assert PayloadBuilder.build_redacted_payload(payload).event == "incident_opened"
    end

    test "keeps the incident_id field" do
      payload = %{
        integration_id: "ig-1",
        provider: :google_ads,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: %{}
      }

      assert PayloadBuilder.build_redacted_payload(payload).incident_id == "inc-1"
    end

    test "keeps the monitor_id field" do
      payload = %{
        integration_id: "ig-1",
        provider: :google_ads,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: %{}
      }

      assert PayloadBuilder.build_redacted_payload(payload).monitor_id == "mon-1"
    end

    test "keeps the workspace_id field" do
      payload = %{
        integration_id: "ig-1",
        provider: :google_ads,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: %{}
      }

      assert PayloadBuilder.build_redacted_payload(payload).workspace_id == "ws-1"
    end

    test "strips secrets from settings (access_token is omitted)" do
      payload = %{
        integration_id: "ig-1",
        provider: :google_ads,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: %{"access_token" => "secret-value"}
      }

      redacted = PayloadBuilder.build_redacted_payload(payload)

      refute Map.has_key?(redacted, "access_token")
    end

    test "includes campaign_ids from settings for selective resume tracking" do
      payload = %{
        integration_id: "ig-1",
        provider: :google_ads,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: %{"campaign_ids" => ["c1", "c2"]}
      }

      redacted = PayloadBuilder.build_redacted_payload(payload)

      assert redacted["campaign_ids"] == ["c1", "c2"]
    end

    test "includes ad_set_ids from settings for selective resume tracking" do
      payload = %{
        integration_id: "ig-1",
        provider: :meta_ads,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: %{"ad_set_ids" => ["as-1"]}
      }

      redacted = PayloadBuilder.build_redacted_payload(payload)

      assert redacted["ad_set_ids"] == ["as-1"]
    end

    test "handles nil settings without raising" do
      payload = %{
        integration_id: "ig-1",
        provider: :slack,
        event: "incident_opened",
        incident_id: "inc-1",
        monitor_id: "mon-1",
        workspace_id: "ws-1",
        settings: nil
      }

      redacted = PayloadBuilder.build_redacted_payload(payload)

      assert redacted.event == "incident_opened"
    end
  end
end
