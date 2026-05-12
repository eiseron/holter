defmodule Holter.System.AdminActionsTest do
  use ExUnit.Case, async: true

  alias Holter.Identity.Models.User
  alias Holter.System.AdminActions
  alias Holter.System.Models.Admin

  @target %User{id: "11111111-1111-1111-1111-111111111111", email: "alice@h.test"}
  @actor %Admin{id: "22222222-2222-2222-2222-222222222222"}
  @sample_now ~U[2026-05-11 12:34:56.789000Z]

  describe "build_promotion_attrs/3" do
    test "uses the target user id" do
      attrs = AdminActions.build_promotion_attrs(@target, @actor, @sample_now)
      assert attrs.user_id == @target.id
    end

    test "records the acting admin id" do
      attrs = AdminActions.build_promotion_attrs(@target, @actor, @sample_now)
      assert attrs.promoted_by_admin_id == @actor.id
    end

    test "truncates promoted_at to the second" do
      attrs = AdminActions.build_promotion_attrs(@target, @actor, @sample_now)
      assert attrs.promoted_at == ~U[2026-05-11 12:34:56Z]
    end

    test "leaves promoted_by_admin_id nil for the bootstrap path" do
      attrs = AdminActions.build_promotion_attrs(@target, nil, @sample_now)
      assert is_nil(attrs.promoted_by_admin_id)
    end
  end

  describe "build_revocation_attrs/2" do
    test "truncates revoked_at to the second" do
      attrs = AdminActions.build_revocation_attrs(@actor, @sample_now)
      assert attrs.revoked_at == ~U[2026-05-11 12:34:56Z]
    end

    test "records the revoking admin id" do
      attrs = AdminActions.build_revocation_attrs(@actor, @sample_now)
      assert attrs.revoked_by_admin_id == @actor.id
    end
  end

  describe "build_audit_diff/3 promote" do
    test "captures the target user id" do
      diff = AdminActions.build_audit_diff(:promote, @target, @actor)
      assert diff["target_user_id"] == @target.id
    end

    test "captures the target email" do
      diff = AdminActions.build_audit_diff(:promote, @target, @actor)
      assert diff["target_email"] == @target.email
    end

    test "captures the acting admin id" do
      diff = AdminActions.build_audit_diff(:promote, @target, @actor)
      assert diff["actor_admin_id"] == @actor.id
    end

    test "records a nil actor_admin_id for the bootstrap path" do
      diff = AdminActions.build_audit_diff(:promote, @target, nil)
      assert is_nil(diff["actor_admin_id"])
    end
  end

  describe "build_audit_diff/3 demote" do
    test "captures the target admin id" do
      target_admin = %Admin{id: "target-id", user_id: "target-user"}
      diff = AdminActions.build_audit_diff(:demote, target_admin, @actor)
      assert diff["target_admin_id"] == "target-id"
    end

    test "captures the target user id from the admin row" do
      target_admin = %Admin{id: "target-id", user_id: "target-user"}
      diff = AdminActions.build_audit_diff(:demote, target_admin, @actor)
      assert diff["target_user_id"] == "target-user"
    end

    test "captures the acting admin id" do
      target_admin = %Admin{id: "target-id", user_id: "target-user"}
      diff = AdminActions.build_audit_diff(:demote, target_admin, @actor)
      assert diff["actor_admin_id"] == @actor.id
    end
  end

  describe "build_audit_log_attrs/2" do
    test "uses the user id from actor_user" do
      params = %{
        actor_user: %User{id: "uid", email: "a@h.test"},
        actor_type: "admin",
        resource: "User:x",
        action: "promote_admin",
        diff: %{}
      }

      attrs = AdminActions.build_audit_log_attrs(params, @sample_now)
      assert attrs.actor_id == "uid"
    end

    test "leaves actor_id nil for system actor" do
      params = %{
        actor_user: nil,
        actor_type: "system",
        resource: "User:bootstrap",
        action: "promote_admin",
        diff: %{}
      }

      attrs = AdminActions.build_audit_log_attrs(params, @sample_now)
      assert is_nil(attrs.actor_id)
    end

    test "preserves the diff payload verbatim" do
      params = %{
        actor_user: nil,
        actor_type: "system",
        resource: "User:x",
        action: "test",
        diff: %{"k" => "v"}
      }

      attrs = AdminActions.build_audit_log_attrs(params, @sample_now)
      assert attrs.diff == %{"k" => "v"}
    end

    test "preserves the occurred_at timestamp at usec precision" do
      params = %{
        actor_user: nil,
        actor_type: "system",
        resource: "User:x",
        action: "test",
        diff: %{}
      }

      attrs = AdminActions.build_audit_log_attrs(params, @sample_now)
      assert attrs.occurred_at == @sample_now
    end
  end
end
