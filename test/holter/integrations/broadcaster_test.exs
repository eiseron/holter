defmodule Holter.Integrations.BroadcasterTest do
  use ExUnit.Case, async: false

  alias Holter.Integrations.Broadcaster

  setup do
    Phoenix.PubSub.subscribe(Holter.PubSub, "integrations:events")
    :ok
  end

  describe "broadcast_dispatch_attempted/2" do
    test "publishes :integration_dispatch_attempted with workspace_id and event" do
      workspace_id = Ecto.UUID.generate()
      Broadcaster.broadcast_dispatch_attempted(workspace_id, "incident_opened")

      assert_receive {:integration_dispatch_attempted,
                      %{workspace_id: ^workspace_id, event: "incident_opened"}}
    end
  end

  describe "broadcast_integration_status_changed/2" do
    test "publishes :integration_status_changed with integration_id and status" do
      integration_id = Ecto.UUID.generate()
      Broadcaster.broadcast_integration_status_changed(integration_id, :reauth_required)

      assert_receive {:integration_status_changed,
                      %{integration_id: ^integration_id, status: :reauth_required}}
    end
  end

  describe "broadcast_integration_dispatched/3" do
    test "publishes :integration_dispatched with integration_id, event, and result on success" do
      integration_id = Ecto.UUID.generate()
      Broadcaster.broadcast_integration_dispatched(integration_id, "incident_opened", :ok)

      assert_receive {:integration_dispatched,
                      %{integration_id: ^integration_id, event: "incident_opened", result: :ok}}
    end

    test "publishes :integration_dispatched with error result on failure" do
      integration_id = Ecto.UUID.generate()

      Broadcaster.broadcast_integration_dispatched(
        integration_id,
        "incident_resolved",
        {:error, :timeout}
      )

      assert_receive {:integration_dispatched,
                      %{integration_id: ^integration_id, result: {:error, :timeout}}}
    end
  end
end
