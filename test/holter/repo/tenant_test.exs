defmodule Holter.Repo.TenantTest do
  use Holter.DataCase, async: true

  alias Holter.Repo.Tenant

  describe "with_workspace/2" do
    test "stamps app.current_workspace_id with the given uuid for the duration of the function" do
      uuid = "11111111-2222-3333-4444-555555555555"

      assert ^uuid = Tenant.with_workspace(uuid, fn -> Tenant.current_workspace_id() end)
    end

    test "returns the inner function's value directly" do
      assert 42 ==
               Tenant.with_workspace("11111111-2222-3333-4444-555555555555", fn -> 42 end)
    end

    test "extracts the id from a struct-shaped argument with an :id field" do
      uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
      workspace = %{id: uuid}

      assert ^uuid = Tenant.with_workspace(workspace, fn -> Tenant.current_workspace_id() end)
    end

    test "raises ArgumentError when given a non-uuid value" do
      assert_raise ArgumentError, ~r/requires a workspace id/, fn ->
        Tenant.with_workspace("not-a-uuid", fn -> :unreachable end)
      end
    end

    test "clears the variable after the wrapper exits" do
      uuid = "11111111-2222-3333-4444-555555555555"
      Tenant.with_workspace(uuid, fn -> :ok end)

      assert is_nil(Tenant.current_workspace_id())
    end

    test "restores the outer workspace id even if the inner block raised" do
      outer = "11111111-1111-1111-1111-111111111111"

      Tenant.with_workspace(outer, fn ->
        try do
          Tenant.with_workspace("22222222-2222-2222-2222-222222222222", fn ->
            raise "boom"
          end)
        rescue
          _ -> :ok
        end

        assert Tenant.current_workspace_id() == outer
      end)
    end

    test "nesting restores the outer workspace id when the inner block exits normally" do
      outer = "11111111-1111-1111-1111-111111111111"
      inner = "22222222-2222-2222-2222-222222222222"

      result =
        Tenant.with_workspace(outer, fn ->
          Tenant.with_workspace(inner, fn -> Tenant.current_workspace_id() end)
          Tenant.current_workspace_id()
        end)

      assert ^outer = result
    end
  end

  describe "with_user/2" do
    test "stamps app.current_user_id with the given uuid for the duration of the function" do
      uuid = "11111111-2222-3333-4444-555555555555"

      assert ^uuid = Tenant.with_user(uuid, fn -> Tenant.current_user_id() end)
    end

    test "returns the inner function's value directly" do
      assert :sentinel ==
               Tenant.with_user("11111111-2222-3333-4444-555555555555", fn -> :sentinel end)
    end

    test "extracts the id from a %User{} struct via the :id field" do
      uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

      assert ^uuid = Tenant.with_user(%{id: uuid}, fn -> Tenant.current_user_id() end)
    end

    test "raises ArgumentError when given a non-uuid value" do
      assert_raise ArgumentError, ~r/requires a user id/, fn ->
        Tenant.with_user("not-a-uuid", fn -> :unreachable end)
      end
    end

    test "clears the variable after the wrapper exits" do
      uuid = "11111111-2222-3333-4444-555555555555"
      Tenant.with_user(uuid, fn -> :ok end)

      assert is_nil(Tenant.current_user_id())
    end

    test "user and workspace contexts compose without interfering" do
      user = "11111111-1111-1111-1111-111111111111"
      workspace = "22222222-2222-2222-2222-222222222222"

      result =
        Tenant.with_user(user, fn ->
          Tenant.with_workspace(workspace, fn ->
            {Tenant.current_user_id(), Tenant.current_workspace_id()}
          end)
        end)

      assert {^user, ^workspace} = result
    end
  end

  describe "with_workspace!/2 and with_user!/2" do
    test "with_workspace!/2 mirrors with_workspace/2 (return shape: inner value)" do
      uuid = "11111111-2222-3333-4444-555555555555"

      assert ^uuid = Tenant.with_workspace!(uuid, fn -> Tenant.current_workspace_id() end)
    end

    test "with_user!/2 mirrors with_user/2 (return shape: inner value)" do
      uuid = "11111111-2222-3333-4444-555555555555"

      assert ^uuid = Tenant.with_user!(uuid, fn -> Tenant.current_user_id() end)
    end
  end

  describe "current_workspace_id/0 and current_user_id/0" do
    test "current_workspace_id/0 returns nil when no tenant has been set on the connection" do
      assert is_nil(Tenant.current_workspace_id())
    end

    test "current_user_id/0 returns nil when no user has been set on the connection" do
      assert is_nil(Tenant.current_user_id())
    end
  end
end
