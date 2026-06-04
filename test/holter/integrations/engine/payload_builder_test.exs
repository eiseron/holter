defmodule Holter.Integrations.Engine.PayloadBuilderTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Engine.PayloadBuilder

  @integration %{
    id: "ig-1",
    provider: :google_ads,
    workspace_id: "ws-1",
    settings: %{"customer_id" => "123"}
  }

  @incident %{id: "inc-1", monitor_id: "mon-1"}

  describe "build_dispatch_payload/3" do
    test "includes integration_id" do
      payload =
        PayloadBuilder.build_dispatch_payload(@integration, "incident_opened", %{
          incident: @incident,
          targets: []
        })

      assert payload.integration_id == "ig-1"
    end

    test "includes the event name" do
      payload =
        PayloadBuilder.build_dispatch_payload(@integration, "incident_opened", %{
          incident: @incident,
          targets: []
        })

      assert payload.event == "incident_opened"
    end

    test "carries the targets list as given" do
      targets = [
        %{"type" => "campaign", "id" => "gads-1", "label" => nil},
        %{"type" => "campaign", "id" => "gads-2", "label" => "Black Friday"}
      ]

      payload =
        PayloadBuilder.build_dispatch_payload(@integration, "incident_opened", %{
          incident: @incident,
          targets: targets
        })

      assert payload.targets == targets
    end

    test "defaults settings to empty map when nil" do
      integration = %{@integration | settings: nil}

      payload =
        PayloadBuilder.build_dispatch_payload(integration, "incident_opened", %{
          incident: @incident,
          targets: []
        })

      assert payload.settings == %{}
    end

    test "includes the monitor_id from the incident" do
      payload =
        PayloadBuilder.build_dispatch_payload(@integration, "incident_opened", %{
          incident: @incident,
          targets: []
        })

      assert payload.monitor_id == "mon-1"
    end
  end

  describe "build_redacted_payload/1" do
    @base_payload %{
      integration_id: "ig-1",
      provider: :google_ads,
      event: "incident_opened",
      incident_id: "inc-1",
      monitor_id: "mon-1",
      workspace_id: "ws-1",
      settings: %{},
      targets: [
        %{"type" => "campaign", "id" => "gads-1", "label" => nil},
        %{"type" => "campaign", "id" => "gads-2", "label" => nil}
      ]
    }

    test "keeps the event field" do
      assert PayloadBuilder.build_redacted_payload(@base_payload).event == "incident_opened"
    end

    test "keeps the incident_id field" do
      assert PayloadBuilder.build_redacted_payload(@base_payload).incident_id == "inc-1"
    end

    test "keeps the monitor_id field" do
      assert PayloadBuilder.build_redacted_payload(@base_payload).monitor_id == "mon-1"
    end

    test "keeps the workspace_id field" do
      assert PayloadBuilder.build_redacted_payload(@base_payload).workspace_id == "ws-1"
    end

    test "extracts target_ids from targets list" do
      redacted = PayloadBuilder.build_redacted_payload(@base_payload)

      assert redacted.target_ids == ["gads-1", "gads-2"]
    end

    test "strips secrets stored in settings (access_token is never echoed)" do
      payload = %{@base_payload | settings: %{"access_token" => "secret-value"}}

      redacted = PayloadBuilder.build_redacted_payload(payload)

      refute Map.has_key?(redacted, "access_token")
    end

    test "handles empty targets list" do
      payload = %{@base_payload | targets: []}

      redacted = PayloadBuilder.build_redacted_payload(payload)

      assert redacted.target_ids == []
    end
  end
end
