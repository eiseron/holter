defmodule HolterWeb.Plugs.RequireScopePlugTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Plugs.RequireScopePlug

  describe "init/1" do
    test "returns the scope when it's known" do
      assert RequireScopePlug.init("read:monitors") == "read:monitors"
    end

    test "raises ArgumentError for an unknown scope (typo guard)" do
      assert_raise ArgumentError, ~r/not a known scope/, fn ->
        RequireScopePlug.init("read:everything")
      end
    end
  end

  describe "call/2" do
    test "passes through when the scope is in :token_scopes" do
      conn =
        build_conn()
        |> assign(:token_scopes, ["read:monitors", "write:monitors"])
        |> RequireScopePlug.call("read:monitors")

      assert conn.state == :unset
    end

    test "responds 403 when the scope is missing" do
      conn =
        build_conn()
        |> assign(:token_scopes, ["read:monitors"])
        |> RequireScopePlug.call("write:monitors")

      assert conn.status == 403
    end

    test "403 body advertises the required scope (helps SDK authors fix it)" do
      conn =
        build_conn()
        |> assign(:token_scopes, ["read:monitors"])
        |> RequireScopePlug.call("write:monitors")

      assert conn.resp_body == ~s({"error":"forbidden","required_scope":"write:monitors"})
    end

    test "responds 403 when :token_scopes assign is missing entirely" do
      conn = build_conn() |> RequireScopePlug.call("read:monitors")

      assert conn.status == 403
    end
  end
end
