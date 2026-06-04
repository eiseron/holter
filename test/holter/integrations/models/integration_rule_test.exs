defmodule Holter.Integrations.Models.IntegrationRuleTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Models.IntegrationRule

  describe "event_types/0" do
    test "includes incident_opened" do
      assert "incident_opened" in IntegrationRule.event_types()
    end

    test "includes incident_resolved" do
      assert "incident_resolved" in IntegrationRule.event_types()
    end

    test "includes monitor_paused" do
      assert "monitor_paused" in IntegrationRule.event_types()
    end

    test "includes monitor_resumed" do
      assert "monitor_resumed" in IntegrationRule.event_types()
    end
  end

  describe "actions/0" do
    test "includes pause_campaign" do
      assert "pause_campaign" in IntegrationRule.actions()
    end

    test "includes resume_campaign" do
      assert "resume_campaign" in IntegrationRule.actions()
    end

    test "includes pause_ad_set" do
      assert "pause_ad_set" in IntegrationRule.actions()
    end

    test "includes resume_ad_set" do
      assert "resume_ad_set" in IntegrationRule.actions()
    end
  end

  describe "target_type_for_action/1" do
    test "maps pause_campaign to campaign" do
      assert IntegrationRule.target_type_for_action("pause_campaign") == "campaign"
    end

    test "maps pause_ad_set to ad_set" do
      assert IntegrationRule.target_type_for_action("pause_ad_set") == "ad_set"
    end

    test "returns nil for unknown action" do
      assert IntegrationRule.target_type_for_action("unknown") == nil
    end
  end

  describe "changeset/2" do
    @valid_attrs %{
      integration_id: Ecto.UUID.generate(),
      monitor_id: Ecto.UUID.generate(),
      event_type: "incident_opened",
      action: "pause_campaign",
      target_id: "gads-1"
    }

    test "derives target_type from action" do
      changeset = IntegrationRule.changeset(%IntegrationRule{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :target_type) == "campaign"
    end

    test "is valid with required fields" do
      assert IntegrationRule.changeset(%IntegrationRule{}, @valid_attrs).valid?
    end

    test "is invalid when integration_id is missing" do
      changeset =
        IntegrationRule.changeset(
          %IntegrationRule{},
          Map.delete(@valid_attrs, :integration_id)
        )

      refute changeset.valid?
    end

    test "is invalid when monitor_id is missing" do
      changeset =
        IntegrationRule.changeset(%IntegrationRule{}, Map.delete(@valid_attrs, :monitor_id))

      refute changeset.valid?
    end

    test "is invalid when event_type is missing" do
      changeset =
        IntegrationRule.changeset(%IntegrationRule{}, Map.delete(@valid_attrs, :event_type))

      refute changeset.valid?
    end

    test "is invalid when target_id is missing" do
      changeset =
        IntegrationRule.changeset(%IntegrationRule{}, Map.delete(@valid_attrs, :target_id))

      refute changeset.valid?
    end

    test "accepts an optional target_label" do
      changeset =
        IntegrationRule.changeset(
          %IntegrationRule{},
          Map.put(@valid_attrs, :target_label, "Black Friday")
        )

      assert changeset.valid?
    end
  end
end
