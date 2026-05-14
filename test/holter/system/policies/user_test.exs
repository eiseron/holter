defmodule Holter.System.Policies.UserTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Models.User
  alias Holter.System.Models.Admin
  alias Holter.System.Policies

  describe ":list" do
    test "allows an active admin" do
      admin = admin_fixture()
      assert :ok = Policies.User.authorize(:list, admin.user, User)
    end

    test "denies a non-admin user" do
      user = user_fixture()
      assert {:error, :unauthorized} = Policies.User.authorize(:list, user, User)
    end

    test "denies a revoked admin" do
      anchor = admin_fixture()
      revoked = admin_fixture()

      revoked
      |> Admin.revocation_changeset(%{
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_by_admin_id: anchor.id
      })
      |> Repo.update!()

      assert {:error, :unauthorized} = Policies.User.authorize(:list, revoked.user, User)
    end
  end

  describe ":read" do
    test "allows an active admin to read any user" do
      admin = admin_fixture()
      target = user_fixture()
      assert :ok = Policies.User.authorize(:read, admin.user, target)
    end

    test "denies a non-admin actor" do
      actor = user_fixture()
      target = user_fixture()
      assert {:error, :unauthorized} = Policies.User.authorize(:read, actor, target)
    end
  end

  describe ":impersonate" do
    test "allows an admin to impersonate another user" do
      admin = admin_fixture()
      target = user_fixture()
      assert :ok = Policies.User.authorize(:impersonate, admin.user, target)
    end

    test "denies a non-admin actor" do
      actor = user_fixture()
      target = user_fixture()
      assert {:error, :unauthorized} = Policies.User.authorize(:impersonate, actor, target)
    end

    test "denies self-impersonation" do
      admin = admin_fixture()

      assert {:error, :cannot_impersonate_self} =
               Policies.User.authorize(:impersonate, admin.user, admin.user)
    end
  end

  describe ":system bypass" do
    test "allows the system actor for any action" do
      target = user_fixture()
      assert :ok = Policies.User.authorize(:read, :system, target)
    end
  end

  describe "unknown actions" do
    test "denies any action outside the policy table" do
      admin = admin_fixture()
      target = user_fixture()
      assert {:error, :unauthorized} = Policies.User.authorize(:delete, admin.user, target)
    end
  end
end
