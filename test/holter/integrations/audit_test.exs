defmodule Holter.Integrations.AuditTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Audit

  @now ~U[2026-05-13 20:00:00.000000Z]
  @actor_id "00000000-0000-0000-0000-000000000001"
  @workspace_id "00000000-0000-0000-0000-000000000002"

  describe "build_connected_audit/3" do
    test "sets actor_type to user" do
      attrs =
        Audit.build_connected_audit(@actor_id, @workspace_id, %{provider: :slack, now: @now})

      assert attrs.actor_type == "user"
    end

    test "sets actor_id from argument" do
      attrs =
        Audit.build_connected_audit(@actor_id, @workspace_id, %{provider: :slack, now: @now})

      assert attrs.actor_id == @actor_id
    end

    test "sets workspace_id from argument" do
      attrs =
        Audit.build_connected_audit(@actor_id, @workspace_id, %{provider: :slack, now: @now})

      assert attrs.workspace_id == @workspace_id
    end

    test "sets action to integrations.connected" do
      attrs =
        Audit.build_connected_audit(@actor_id, @workspace_id, %{provider: :slack, now: @now})

      assert attrs.action == "integrations.connected"
    end

    test "sets resource to integration:<provider>" do
      attrs =
        Audit.build_connected_audit(@actor_id, @workspace_id, %{provider: :slack, now: @now})

      assert attrs.resource == "integration:slack"
    end

    test "sets occurred_at from context map" do
      attrs =
        Audit.build_connected_audit(@actor_id, @workspace_id, %{provider: :slack, now: @now})

      assert attrs.occurred_at == @now
    end
  end

  describe "build_disconnected_audit/3" do
    test "sets actor_type to user" do
      attrs =
        Audit.build_disconnected_audit(@actor_id, @workspace_id, %{
          provider: :google_ads,
          now: @now
        })

      assert attrs.actor_type == "user"
    end

    test "sets action to integrations.disconnected" do
      attrs =
        Audit.build_disconnected_audit(@actor_id, @workspace_id, %{
          provider: :google_ads,
          now: @now
        })

      assert attrs.action == "integrations.disconnected"
    end

    test "sets resource to integration:<provider>" do
      attrs =
        Audit.build_disconnected_audit(@actor_id, @workspace_id, %{
          provider: :google_ads,
          now: @now
        })

      assert attrs.resource == "integration:google_ads"
    end

    test "sets workspace_id from argument" do
      attrs =
        Audit.build_disconnected_audit(@actor_id, @workspace_id, %{
          provider: :google_ads,
          now: @now
        })

      assert attrs.workspace_id == @workspace_id
    end
  end

  describe "build_action_dispatched_audit/3" do
    test "sets actor_type to system" do
      attrs =
        Audit.build_action_dispatched_audit(@workspace_id, :slack, %{
          event: "incident_opened",
          now: @now
        })

      assert attrs.actor_type == "system"
    end

    test "sets actor_id to nil" do
      attrs =
        Audit.build_action_dispatched_audit(@workspace_id, :slack, %{
          event: "incident_opened",
          now: @now
        })

      assert is_nil(attrs.actor_id)
    end

    test "sets action to integrations.action_dispatched" do
      attrs =
        Audit.build_action_dispatched_audit(@workspace_id, :slack, %{
          event: "incident_opened",
          now: @now
        })

      assert attrs.action == "integrations.action_dispatched"
    end

    test "includes the event in diff" do
      attrs =
        Audit.build_action_dispatched_audit(@workspace_id, :slack, %{
          event: "incident_resolved",
          now: @now
        })

      assert attrs.diff["event"] == "incident_resolved"
    end

    test "sets workspace_id from argument" do
      attrs =
        Audit.build_action_dispatched_audit(@workspace_id, :slack, %{
          event: "incident_opened",
          now: @now
        })

      assert attrs.workspace_id == @workspace_id
    end
  end

  describe "build_reauth_failed_audit/3" do
    test "sets actor_type to system" do
      attrs = Audit.build_reauth_failed_audit(@workspace_id, :meta_ads, %{now: @now})

      assert attrs.actor_type == "system"
    end

    test "sets actor_id to nil" do
      attrs = Audit.build_reauth_failed_audit(@workspace_id, :meta_ads, %{now: @now})

      assert is_nil(attrs.actor_id)
    end

    test "sets action to integrations.reauth_failed" do
      attrs = Audit.build_reauth_failed_audit(@workspace_id, :meta_ads, %{now: @now})

      assert attrs.action == "integrations.reauth_failed"
    end

    test "sets resource to integration:<provider>" do
      attrs = Audit.build_reauth_failed_audit(@workspace_id, :meta_ads, %{now: @now})

      assert attrs.resource == "integration:meta_ads"
    end

    test "sets occurred_at from context map" do
      attrs = Audit.build_reauth_failed_audit(@workspace_id, :meta_ads, %{now: @now})

      assert attrs.occurred_at == @now
    end
  end
end
