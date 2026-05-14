defmodule Holter.System.Policies.FeatureFlagTest do
  use Holter.DataCase, async: true

  alias Holter.System.Models.Admin
  alias Holter.System.Policies

  describe ":list" do
    test "allows an active admin" do
      admin = admin_fixture()
      assert :ok = Policies.FeatureFlag.authorize(:list, admin.user, FunWithFlags.Flag)
    end

    test "denies a non-admin user" do
      user = user_fixture()

      assert {:error, :unauthorized} =
               Policies.FeatureFlag.authorize(:list, user, FunWithFlags.Flag)
    end
  end

  describe ":read" do
    test "allows an active admin to read a flag" do
      admin = admin_fixture()
      flag = %FunWithFlags.Flag{name: :test, gates: []}
      assert :ok = Policies.FeatureFlag.authorize(:read, admin.user, flag)
    end

    test "denies a non-admin actor" do
      actor = user_fixture()
      flag = %FunWithFlags.Flag{name: :test, gates: []}
      assert {:error, :unauthorized} = Policies.FeatureFlag.authorize(:read, actor, flag)
    end
  end

  describe ":update" do
    test "allows an active admin to update a flag" do
      admin = admin_fixture()
      flag = %FunWithFlags.Flag{name: :test, gates: []}
      assert :ok = Policies.FeatureFlag.authorize(:update, admin.user, flag)
    end

    test "denies a non-admin actor" do
      actor = user_fixture()
      flag = %FunWithFlags.Flag{name: :test, gates: []}
      assert {:error, :unauthorized} = Policies.FeatureFlag.authorize(:update, actor, flag)
    end
  end

  describe ":system bypass" do
    test "allows the system actor for any action" do
      flag = %FunWithFlags.Flag{name: :test, gates: []}
      assert :ok = Policies.FeatureFlag.authorize(:read, :system, flag)
    end
  end

  describe "unknown actions" do
    test "denies any action outside the policy table" do
      admin = admin_fixture()
      flag = %FunWithFlags.Flag{name: :test, gates: []}
      assert {:error, :unauthorized} = Policies.FeatureFlag.authorize(:delete, admin.user, flag)
    end
  end

  describe "invalid subject" do
    test "denies admin when subject is not a FunWithFlags.Flag" do
      admin = admin_fixture()
      assert {:error, :unauthorized} = Policies.FeatureFlag.authorize(:read, admin.user, :invalid)
    end
  end

  describe "revoked admin" do
    test "denies a revoked admin" do
      anchor = admin_fixture()
      revoked = admin_fixture()

      revoked
      |> Admin.revocation_changeset(%{
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_by_admin_id: anchor.id
      })
      |> Repo.update!()

      flag = %FunWithFlags.Flag{name: :test, gates: []}

      assert {:error, :unauthorized} =
               Policies.FeatureFlag.authorize(:update, revoked.user, flag)
    end
  end
end
