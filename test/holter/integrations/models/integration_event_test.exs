defmodule Holter.Integrations.Models.IntegrationEventTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.Models.IntegrationEvent

  describe "insert_changeset/2" do
    test "accepts valid attributes" do
      integration = integration_fixture(workspace_id: workspace_fixture().id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        integration_id: integration.id,
        direction: :outbound,
        action: "pause_campaign",
        target: "campaign:gads-12345",
        status: :success,
        duration_ms: 200,
        occurred_at: now
      }

      cs = IntegrationEvent.insert_changeset(%IntegrationEvent{}, attrs)
      assert cs.valid?
    end

    test "requires integration_id" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        IntegrationEvent.insert_changeset(%IntegrationEvent{}, %{
          direction: :outbound,
          action: "pause_campaign",
          status: :success,
          occurred_at: now
        })

      assert "can't be blank" in errors_on(cs).integration_id
    end

    test "requires direction" do
      integration = integration_fixture(workspace_id: workspace_fixture().id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        IntegrationEvent.insert_changeset(%IntegrationEvent{}, %{
          integration_id: integration.id,
          action: "pause_campaign",
          status: :success,
          occurred_at: now
        })

      assert "can't be blank" in errors_on(cs).direction
    end

    test "rejects invalid direction" do
      integration = integration_fixture(workspace_id: workspace_fixture().id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        IntegrationEvent.insert_changeset(%IntegrationEvent{}, %{
          integration_id: integration.id,
          direction: :sideways,
          action: "pause_campaign",
          status: :success,
          occurred_at: now
        })

      assert "is invalid" in errors_on(cs).direction
    end

    test "rejects negative duration_ms" do
      integration = integration_fixture(workspace_id: workspace_fixture().id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        IntegrationEvent.insert_changeset(%IntegrationEvent{}, %{
          integration_id: integration.id,
          direction: :outbound,
          action: "pause_campaign",
          status: :success,
          duration_ms: -1,
          occurred_at: now
        })

      assert "must be greater than or equal to 0" in errors_on(cs).duration_ms
    end

    test "requires occurred_at" do
      integration = integration_fixture(workspace_id: workspace_fixture().id)

      cs =
        IntegrationEvent.insert_changeset(%IntegrationEvent{}, %{
          integration_id: integration.id,
          direction: :outbound,
          action: "pause_campaign",
          status: :success
        })

      assert "can't be blank" in errors_on(cs).occurred_at
    end
  end

  describe "directions/0" do
    test "includes :outbound" do
      assert :outbound in IntegrationEvent.directions()
    end

    test "includes :inbound" do
      assert :inbound in IntegrationEvent.directions()
    end
  end

  describe "statuses/0" do
    test "includes :success" do
      assert :success in IntegrationEvent.statuses()
    end

    test "includes :failed" do
      assert :failed in IntegrationEvent.statuses()
    end
  end
end
