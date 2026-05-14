defmodule Holter.System.WorkspacesTest do
  use Holter.DataCase, async: true

  alias Holter.RLSHelpers
  alias Holter.System.Workspaces

  describe "list_workspaces/1" do
    test "returns all workspaces with default pagination" do
      %{workspace: ws} = verified_user_fixture()
      %{data: workspaces, meta: _meta} = Workspaces.list_workspaces()
      slugs = Enum.map(workspaces, & &1.slug)
      assert ws.slug in slugs
    end

    test "returns page number in metadata" do
      verified_user_fixture()
      %{meta: meta} = Workspaces.list_workspaces()
      assert meta.page == 1
    end

    test "returns page size in metadata" do
      verified_user_fixture()
      %{meta: meta} = Workspaces.list_workspaces()
      assert meta.page_size == 25
    end

    test "returns exact total count matching inserted workspaces" do
      verified_user_fixture()
      %{meta: meta} = Workspaces.list_workspaces()
      assert meta.total == 1
    end

    test "filters by name substring" do
      %{workspace: ws} = verified_user_fixture()
      %{data: workspaces} = Workspaces.list_workspaces(%{name: ws.name})
      assert Enum.any?(workspaces, fn w -> w.id == ws.id end)
    end

    test "filters by slug substring" do
      %{workspace: ws} = verified_user_fixture()
      %{data: workspaces} = Workspaces.list_workspaces(%{name: ws.slug})
      assert Enum.any?(workspaces, fn w -> w.id == ws.id end)
    end

    test "returns empty when no workspaces match" do
      %{data: workspaces} = Workspaces.list_workspaces(%{name: "zzz_nonexistent_zzz"})
      assert workspaces == []
    end

    test "sorts by name ascending" do
      verified_user_fixture()
      verified_user_fixture()
      %{data: workspaces} = Workspaces.list_workspaces(%{sort_by: "name", sort_dir: "asc"})
      names = Enum.map(workspaces, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "get_with_associations!/1" do
    test "returns the workspace with matching id" do
      %{workspace: ws} = verified_user_fixture()
      %{workspace: loaded} = Workspaces.get_with_associations!(ws.id)
      assert loaded.id == ws.id
    end

    test "returns the monitoring profile for the workspace" do
      %{workspace: ws} = verified_user_fixture()
      %{monitoring_profile: profile} = Workspaces.get_with_associations!(ws.id)
      assert profile.workspace_id == ws.id
    end

    test "returns the delivery profile for the workspace" do
      %{workspace: ws} = verified_user_fixture()
      %{delivery_profile: profile} = Workspaces.get_with_associations!(ws.id)
      assert profile.workspace_id == ws.id
    end

    test "lists the workspace owner among members" do
      %{user: user, workspace: ws} = verified_user_fixture()
      %{members: members} = Workspaces.get_with_associations!(ws.id)
      emails = Enum.map(members, & &1.user_email)
      assert user.email in emails
    end

    test "exposes the role for each member" do
      %{workspace: ws} = verified_user_fixture()
      %{members: [member | _]} = Workspaces.get_with_associations!(ws.id)
      assert member.role in [:owner, :admin, :member]
    end

    test "returns empty monitors list when none exist" do
      %{workspace: ws} = verified_user_fixture()
      %{monitors: monitors} = Workspaces.get_with_associations!(ws.id)
      assert monitors == []
    end

    test "lists monitors that belong to the workspace" do
      %{user: owner, workspace: ws} = verified_user_fixture()

      _monitor =
        Holter.MonitoringFixtures.monitor_fixture(
          owner: owner,
          workspace: ws,
          interval_seconds: 600
        )

      %{monitors: monitors} = Workspaces.get_with_associations!(ws.id)
      assert length(monitors) == 1
    end

    test "returns empty audit log when no admin actions exist" do
      %{workspace: ws} = verified_user_fixture()
      %{audit_log: log} = Workspaces.get_with_associations!(ws.id)
      assert log == []
    end

    test "returns audit log entries scoped to the workspace resource" do
      %{workspace: ws} = verified_user_fixture()
      audit_log_fixture(%{resource: "Workspace:" <> ws.id, action: "unique_ws_action"})
      %{audit_log: [entry | _]} = Workspaces.get_with_associations!(ws.id)
      assert entry.action == "unique_ws_action"
    end

    test "does not leak audit log entries from other workspaces" do
      %{workspace: ws_a} = verified_user_fixture()
      %{workspace: ws_b} = verified_user_fixture()
      audit_log_fixture(%{resource: "Workspace:" <> ws_b.id, action: "other_ws_action"})
      %{audit_log: log} = Workspaces.get_with_associations!(ws_a.id)
      assert Enum.all?(log, fn entry -> entry.action != "other_ws_action" end)
    end

    test "raises Ecto.NoResultsError when the workspace does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_with_associations!("00000000-0000-0000-0000-000000000000")
      end
    end
  end

  describe "get_with_associations!/1 under holter_app RLS" do
    test "lists members of the workspace even with no current_user context" do
      %{user: owner, workspace: ws} = verified_user_fixture()
      RLSHelpers.setup_app_role()
      %{members: members} = Workspaces.get_with_associations!(ws.id)
      assert Enum.any?(members, fn m -> m.user_email == owner.email end)
    end

    test "lists monitors of the workspace under holter_app role" do
      %{user: owner, workspace: ws} = verified_user_fixture()

      _monitor =
        Holter.MonitoringFixtures.monitor_fixture(
          owner: owner,
          workspace: ws,
          interval_seconds: 600
        )

      RLSHelpers.setup_app_role()
      %{monitors: monitors} = Workspaces.get_with_associations!(ws.id)
      assert length(monitors) == 1
    end

    test "returns the workspace itself under holter_app role" do
      %{workspace: ws} = verified_user_fixture()
      RLSHelpers.setup_app_role()
      %{workspace: loaded} = Workspaces.get_with_associations!(ws.id)
      assert loaded.id == ws.id
    end
  end
end
