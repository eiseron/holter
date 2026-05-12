defmodule Holter.System.UsersGetWithAssociationsTest do
  use Holter.DataCase, async: true

  alias Holter.System.Users

  describe "get_with_associations!/1" do
    test "returns the user struct" do
      %{user: user} = verified_user_fixture()
      %{user: returned} = Users.get_with_associations!(user.id)
      assert returned.id == user.id
    end

    test "returns workspaces the user is a member of" do
      %{user: user, workspace: workspace} = verified_user_fixture()
      %{memberships: memberships} = Users.get_with_associations!(user.id)
      ids = Enum.map(memberships, & &1.workspace.id)
      assert workspace.id in ids
    end

    test "includes the role on each membership" do
      %{user: user} = verified_user_fixture()
      %{memberships: [first | _]} = Users.get_with_associations!(user.id)
      assert first.role in [:owner, :admin, :member]
    end

    test "raises Ecto.NoResultsError for an unknown user id" do
      assert_raise Ecto.NoResultsError, fn ->
        Users.get_with_associations!("00000000-0000-0000-0000-000000000000")
      end
    end
  end

  describe "audit log filtering" do
    test "returns audit rows whose resource references the user" do
      %{user: user} = verified_user_fixture()
      audit_log_fixture(%{resource: "User:" <> user.id, action: "test_action"})
      _other = audit_log_fixture(%{resource: "User:other", action: "ignored_action"})

      %{audit_log: rows} = Users.get_with_associations!(user.id)
      actions = Enum.map(rows, & &1.action)
      assert "test_action" in actions
      refute "ignored_action" in actions
    end

    test "orders audit rows newest occurred_at first" do
      %{user: user} = verified_user_fixture()

      audit_log_fixture(%{
        resource: "User:" <> user.id,
        action: "older",
        occurred_at: ~U[2026-01-01 00:00:00.000000Z]
      })

      audit_log_fixture(%{
        resource: "User:" <> user.id,
        action: "newer",
        occurred_at: ~U[2026-06-01 00:00:00.000000Z]
      })

      %{audit_log: [first | _]} = Users.get_with_associations!(user.id)
      assert first.action == "newer"
    end

    test "returns at most 50 audit rows" do
      %{user: user} = verified_user_fixture()

      for i <- 1..55 do
        audit_log_fixture(%{
          resource: "User:" <> user.id,
          action: "action_#{i}"
        })
      end

      %{audit_log: rows} = Users.get_with_associations!(user.id)
      assert length(rows) == 50
    end
  end
end
