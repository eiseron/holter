defmodule Holter.System.Policies.AdminTest do
  use Holter.DataCase, async: true

  alias Holter.System.Models.Admin
  alias Holter.System.Policies

  describe ":enter_admin" do
    test "allows an active admin" do
      admin = admin_fixture()
      assert :ok = Policies.Admin.authorize(:enter_admin, admin.user, admin.user)
    end

    test "denies a non-admin user" do
      user = user_fixture()
      assert {:error, :unauthorized} = Policies.Admin.authorize(:enter_admin, user, user)
    end
  end

  describe ":promote" do
    test "allows an admin to promote a non-admin" do
      admin = admin_fixture()
      target = user_fixture()
      assert :ok = Policies.Admin.authorize(:promote, admin.user, target)
    end

    test "denies promoting someone who is already an admin" do
      admin = admin_fixture()
      existing = admin_fixture()

      assert {:error, :already_admin} =
               Policies.Admin.authorize(:promote, admin.user, existing.user)
    end

    test "denies a non-admin actor" do
      actor = user_fixture()
      target = user_fixture()
      assert {:error, :unauthorized} = Policies.Admin.authorize(:promote, actor, target)
    end
  end

  describe ":demote" do
    test "allows an admin to demote another admin" do
      actor = admin_fixture()
      target = admin_fixture()
      assert :ok = Policies.Admin.authorize(:demote, actor.user, target)
    end

    test "refuses self-demotion" do
      admin = admin_fixture()
      assert {:error, :cannot_self_demote} = Policies.Admin.authorize(:demote, admin.user, admin)
    end

    test "denies a non-admin actor" do
      actor = user_fixture()
      target = admin_fixture()
      assert {:error, :unauthorized} = Policies.Admin.authorize(:demote, actor, target)
    end
  end

  describe ":list_admins" do
    test "allows an active admin" do
      admin = admin_fixture()
      assert :ok = Policies.Admin.authorize(:list_admins, admin.user, Admin)
    end

    test "denies a non-admin" do
      user = user_fixture()
      assert {:error, :unauthorized} = Policies.Admin.authorize(:list_admins, user, Admin)
    end
  end

  describe ":read_audit_log" do
    test "allows an active admin" do
      admin = admin_fixture()
      assert :ok = Policies.Admin.authorize(:read_audit_log, admin.user, Admin)
    end

    test "denies a non-admin" do
      user = user_fixture()
      assert {:error, :unauthorized} = Policies.Admin.authorize(:read_audit_log, user, Admin)
    end
  end

  describe ":system bypass" do
    test "allows the system actor for any action" do
      target = user_fixture()
      assert :ok = Policies.Admin.authorize(:promote, :system, target)
    end
  end
end
