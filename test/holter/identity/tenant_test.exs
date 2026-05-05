defmodule Holter.Identity.TenantTest do
  use ExUnit.Case, async: true

  alias Holter.Identity.Tenant

  describe "workspace_session_var/0" do
    test "returns the postgres setting key used by workspace-keyed RLS policies" do
      assert Tenant.workspace_session_var() == "app.current_workspace_id"
    end
  end

  describe "user_session_var/0" do
    test "returns the postgres setting key used by user-keyed RLS policies" do
      assert Tenant.user_session_var() == "app.current_user_id"
    end
  end

  describe "parse_workspace_id/1" do
    test "accepts a canonical lowercase UUID string" do
      uuid = "11111111-2222-3333-4444-555555555555"

      assert {:ok, ^uuid} = Tenant.parse_workspace_id(uuid)
    end

    test "downcases an UPPERCASE UUID to canonical form" do
      assert {:ok, "abcdef01-2345-6789-abcd-ef0123456789"} =
               Tenant.parse_workspace_id("ABCDEF01-2345-6789-ABCD-EF0123456789")
    end

    test "extracts the id from a struct-like map with an :id field" do
      uuid = "11111111-2222-3333-4444-555555555555"

      assert {:ok, ^uuid} = Tenant.parse_workspace_id(%{id: uuid})
    end

    test "rejects a non-uuid string" do
      assert {:error, :invalid_workspace_id} = Tenant.parse_workspace_id("not-a-uuid")
    end

    test "rejects nil" do
      assert {:error, :invalid_workspace_id} = Tenant.parse_workspace_id(nil)
    end

    test "rejects a map without an :id field" do
      assert {:error, :invalid_workspace_id} = Tenant.parse_workspace_id(%{slug: "x"})
    end

    test "rejects an integer" do
      assert {:error, :invalid_workspace_id} = Tenant.parse_workspace_id(42)
    end

    test "rejects a SQL-injection attempt smuggled as a workspace id" do
      assert {:error, :invalid_workspace_id} =
               Tenant.parse_workspace_id("'; DROP TABLE monitors; --")
    end
  end

  describe "parse_user_id/1" do
    test "accepts a canonical UUID string" do
      uuid = "11111111-2222-3333-4444-555555555555"

      assert {:ok, ^uuid} = Tenant.parse_user_id(uuid)
    end

    test "extracts the id from a %User{} struct via the :id field" do
      uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

      assert {:ok, ^uuid} = Tenant.parse_user_id(%{id: uuid})
    end

    test "rejects a non-uuid string with the user-specific error tag" do
      assert {:error, :invalid_user_id} = Tenant.parse_user_id("not-a-uuid")
    end

    test "rejects nil with the user-specific error tag" do
      assert {:error, :invalid_user_id} = Tenant.parse_user_id(nil)
    end
  end
end
