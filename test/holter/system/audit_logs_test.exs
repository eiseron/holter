defmodule Holter.System.AuditLogsTest do
  use Holter.DataCase, async: true

  alias Holter.System.AuditLogs
  alias Holter.System.Models.AuditLog

  describe "log!/1,2" do
    test "stores the actor_id when actor_user is provided" do
      user = user_fixture()

      audit =
        AuditLogs.log!(%{
          actor_user: user,
          actor_type: "admin",
          resource: "User:" <> user.id,
          action: "test_action",
          diff: %{}
        })

      assert audit.actor_id == user.id
    end

    test "round-trips the diff payload" do
      user = user_fixture()

      audit =
        AuditLogs.log!(%{
          actor_user: user,
          actor_type: "admin",
          resource: "User:x",
          action: "test_action",
          diff: %{"key" => "value"}
        })

      assert audit.diff == %{"key" => "value"}
    end

    test "stamps the provided occurred_at timestamp" do
      user = user_fixture()
      now = DateTime.utc_now()

      audit =
        AuditLogs.log!(
          %{
            actor_user: user,
            actor_type: "admin",
            resource: "User:x",
            action: "test",
            diff: %{}
          },
          now
        )

      assert DateTime.compare(audit.occurred_at, now) == :eq
    end

    test "rejects admin actor_type without an actor_id" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        AuditLogs.log!(%{
          actor_user: nil,
          actor_type: "admin",
          resource: "User:x",
          action: "test",
          diff: %{}
        })
      end
    end

    test "rejects system actor_type with an actor_id" do
      user = user_fixture()

      assert_raise Ecto.InvalidChangesetError, fn ->
        AuditLogs.log!(%{
          actor_user: user,
          actor_type: "system",
          resource: "User:x",
          action: "test",
          diff: %{}
        })
      end
    end

    test "accepts system actor_type with nil actor for the bootstrap path" do
      audit =
        AuditLogs.log!(%{
          actor_user: nil,
          actor_type: "system",
          resource: "User:bootstrap",
          action: "promote_admin",
          diff: %{}
        })

      assert is_nil(audit.actor_id)
    end
  end

  describe "append-only invariant" do
    test "exposes no update_* function" do
      function_names =
        AuditLogs.__info__(:functions)
        |> Enum.map(fn {name, _arity} -> Atom.to_string(name) end)

      refute Enum.any?(function_names, &String.starts_with?(&1, "update"))
    end

    test "exposes no delete_* function" do
      function_names =
        AuditLogs.__info__(:functions)
        |> Enum.map(fn {name, _arity} -> Atom.to_string(name) end)

      refute Enum.any?(function_names, &String.starts_with?(&1, "delete"))
    end

    test "audit_logs schema has no updated_at field" do
      refute :updated_at in AuditLog.__schema__(:fields)
    end
  end

  describe "list_audit_logs/1" do
    test "returns rows newest occurred_at first" do
      _older =
        audit_log_fixture(%{
          resource: "User:older",
          occurred_at: ~U[2026-01-01 00:00:00.000000Z]
        })

      _newer =
        audit_log_fixture(%{
          resource: "User:newer",
          occurred_at: ~U[2026-02-01 00:00:00.000000Z]
        })

      [first | _] = AuditLogs.list_audit_logs()
      assert first.resource == "User:newer"
    end

    test "filters by resource" do
      _other = audit_log_fixture(%{resource: "User:other"})
      target = audit_log_fixture(%{resource: "User:target"})

      [returned] = AuditLogs.list_audit_logs(resource: "User:target")
      assert returned.id == target.id
    end

    test "filters by action" do
      _other = audit_log_fixture(%{action: "other_action"})
      target = audit_log_fixture(%{action: "target_action"})

      [returned] = AuditLogs.list_audit_logs(action: "target_action")
      assert returned.id == target.id
    end
  end
end
