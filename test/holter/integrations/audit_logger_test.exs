defmodule Holter.Integrations.AuditLoggerTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.AuditLogger
  alias Holter.Integrations.Models.IntegrationAuditLog
  alias Holter.Repo

  defp entries(action) do
    Repo.all(from a in IntegrationAuditLog, where: a.action == ^action)
  end

  describe "log_connected/3" do
    test "inserts an audit entry with action integrations.connected" do
      user = user_fixture()
      ws = workspace_fixture()

      AuditLogger.log_connected(user.id, ws.id, :slack)

      [entry] = entries("integrations.connected")
      assert entry.action == "integrations.connected"
    end

    test "stores actor_id matching the user" do
      user = user_fixture()
      ws = workspace_fixture()

      AuditLogger.log_connected(user.id, ws.id, :slack)

      [entry] = entries("integrations.connected")
      assert entry.actor_id == user.id
    end

    test "stores workspace_id matching the workspace" do
      user = user_fixture()
      ws = workspace_fixture()

      AuditLogger.log_connected(user.id, ws.id, :google_ads)

      [entry] = entries("integrations.connected")
      assert entry.workspace_id == ws.id
    end

    test "sets resource to integration:<provider>" do
      user = user_fixture()
      ws = workspace_fixture()

      AuditLogger.log_connected(user.id, ws.id, :meta_ads)

      [entry] = entries("integrations.connected")
      assert entry.resource == "integration:meta_ads"
    end
  end

  describe "log_disconnected/3" do
    test "inserts an audit entry with action integrations.disconnected" do
      user = user_fixture()
      ws = workspace_fixture()

      AuditLogger.log_disconnected(user.id, ws.id, :slack)

      [entry] = entries("integrations.disconnected")
      assert entry.action == "integrations.disconnected"
    end

    test "stores actor_type user" do
      user = user_fixture()
      ws = workspace_fixture()

      AuditLogger.log_disconnected(user.id, ws.id, :slack)

      [entry] = entries("integrations.disconnected")
      assert entry.actor_type == "user"
    end
  end

  describe "log_action_dispatched/3" do
    test "inserts an audit entry with action integrations.action_dispatched" do
      ws = workspace_fixture()

      AuditLogger.log_action_dispatched(ws.id, :slack, "incident_opened")

      [entry] = entries("integrations.action_dispatched")
      assert entry.action == "integrations.action_dispatched"
    end

    test "sets actor_type to system" do
      ws = workspace_fixture()

      AuditLogger.log_action_dispatched(ws.id, :slack, "incident_resolved")

      [entry] = entries("integrations.action_dispatched")
      assert entry.actor_type == "system"
    end

    test "stores event name in diff" do
      ws = workspace_fixture()

      AuditLogger.log_action_dispatched(ws.id, :slack, "incident_opened")

      [entry] = entries("integrations.action_dispatched")
      assert entry.diff["event"] == "incident_opened"
    end
  end

  describe "log_reauth_failed/2" do
    test "inserts an audit entry with action integrations.reauth_failed" do
      ws = workspace_fixture()

      AuditLogger.log_reauth_failed(ws.id, :google_ads)

      [entry] = entries("integrations.reauth_failed")
      assert entry.action == "integrations.reauth_failed"
    end

    test "sets actor_type to system" do
      ws = workspace_fixture()

      AuditLogger.log_reauth_failed(ws.id, :meta_ads)

      [entry] = entries("integrations.reauth_failed")
      assert entry.actor_type == "system"
    end

    test "sets resource to integration:<provider>" do
      ws = workspace_fixture()

      AuditLogger.log_reauth_failed(ws.id, :google_ads)

      [entry] = entries("integrations.reauth_failed")
      assert entry.resource == "integration:google_ads"
    end
  end
end
