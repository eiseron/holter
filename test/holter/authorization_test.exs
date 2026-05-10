defmodule Holter.AuthorizationTest do
  use Holter.DataCase, async: true

  alias Holter.Authorization
  alias Holter.Identity.Models.ApiToken
  alias Holter.Identity.Scopes
  alias Holter.Monitoring.Models.Monitor

  describe ":system actor" do
    test "is authorized to :read a monitor instance" do
      monitor = %Monitor{workspace_id: Ecto.UUID.generate()}

      assert_authorized(:system, :read, monitor)
    end

    test "is authorized to :delete a monitor instance" do
      monitor = %Monitor{workspace_id: Ecto.UUID.generate()}

      assert_authorized(:system, :delete, monitor)
    end
  end

  describe ":read on a Monitor instance" do
    test "owner of the workspace passes" do
      {user, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :read, monitor)
    end

    test "admin of the workspace passes" do
      {user, workspace} = workspace_with_role(:admin)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :read, monitor)
    end

    test "member of the workspace passes" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :read, monitor)
    end

    test "user without membership is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)
      outsider = non_member_user()

      assert_forbidden(outsider, :read, monitor)
    end
  end

  describe ":write on a Monitor instance" do
    test "owner passes" do
      {user, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :write, monitor)
    end

    test "admin passes" do
      {user, workspace} = workspace_with_role(:admin)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :write, monitor)
    end

    test "member passes" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :write, monitor)
    end

    test "user without membership is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)
      outsider = non_member_user()

      assert_forbidden(outsider, :write, monitor)
    end
  end

  describe ":delete on a Monitor instance" do
    test "owner passes" do
      {user, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :delete, monitor)
    end

    test "admin passes" do
      {user, workspace} = workspace_with_role(:admin)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_authorized(user, :delete, monitor)
    end

    test "member is forbidden" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_forbidden(user, :delete, monitor)
    end

    test "user without membership is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)
      outsider = non_member_user()

      assert_forbidden(outsider, :delete, monitor)
    end
  end

  describe "unsupported actions on Monitor" do
    test ":admin on a monitor instance is forbidden even for an owner" do
      {user, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_forbidden(user, :admin, monitor)
    end

    test ":destroy on a monitor instance is forbidden even for an owner" do
      {user, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)

      assert_forbidden(user, :destroy, monitor)
    end
  end

  describe "Monitor intent subject {Monitor, workspace}" do
    test ":write passes for a member" do
      {user, workspace} = workspace_with_role(:member)

      assert_authorized(user, :write, {Monitor, workspace})
    end

    test ":write is forbidden for a non-member" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()

      assert_forbidden(outsider, :write, {Monitor, workspace})
    end

    test ":read passes for a member" do
      {user, workspace} = workspace_with_role(:member)

      assert_authorized(user, :read, {Monitor, workspace})
    end

    test ":read is forbidden for a non-member" do
      {_owner, workspace} = workspace_with_role(:owner)
      outsider = non_member_user()

      assert_forbidden(outsider, :read, {Monitor, workspace})
    end
  end

  describe "ApiToken actor" do
    test "passes when the token's user is a member and the action's scope is carried" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)
      token = %ApiToken{user: user, scopes: ["read:monitors"]}

      assert_authorized(token, :read, monitor)
    end

    test "is forbidden when the token does not carry the action's scope" do
      {user, workspace} = workspace_with_role(:member)
      monitor = monitor_fixture(workspace_id: workspace.id)
      token = %ApiToken{user: user, scopes: ["read:monitors"]}

      assert_forbidden(token, :write, monitor)
    end

    test "is forbidden when the token's user is not a member" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)
      outsider = non_member_user()
      token = %ApiToken{user: outsider, scopes: Scopes.all()}

      assert_forbidden(token, :read, monitor)
    end

    test "is forbidden when the user association is not preloaded" do
      {_owner, workspace} = workspace_with_role(:owner)
      monitor = monitor_fixture(workspace_id: workspace.id)
      token = %ApiToken{scopes: Scopes.all()}

      assert_forbidden(token, :read, monitor)
    end
  end

  describe "scope_for/2" do
    test "maps :read on Monitor to read:monitors" do
      assert Authorization.scope_for(:read, Monitor) == "read:monitors"
    end

    test "maps :write on Monitor to write:monitors" do
      assert Authorization.scope_for(:write, Monitor) == "write:monitors"
    end

    test "maps :delete on Monitor to write:monitors" do
      assert Authorization.scope_for(:delete, Monitor) == "write:monitors"
    end

    test "returns nil for an unknown subject module" do
      assert Authorization.scope_for(:read, UnknownModule) == nil
    end
  end

  describe "unknown actor" do
    test "is forbidden" do
      monitor = %Monitor{workspace_id: Ecto.UUID.generate()}

      assert_forbidden(:not_an_actor, :read, monitor)
    end
  end
end
