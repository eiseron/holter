defmodule HolterWeb.Plugs.RequireWorkspaceMemberPlugTest do
  use HolterWeb.ConnCase, async: false

  alias HolterWeb.Plugs.RequireWorkspaceMemberPlug

  describe "no :workspace_slug in path_params" do
    test "passes through (resource-id routes rely on RLS)" do
      conn =
        build_conn()
        |> assign(:current_workspace, %{id: "ignored"})
        |> with_path_params(%{})
        |> RequireWorkspaceMemberPlug.call([])

      assert conn.state == :unset
    end
  end

  describe "slug resolves to the same workspace as the token" do
    test "passes through unchanged" do
      workspace = workspace_fixture(slug: "matching-slug")

      conn =
        build_conn()
        |> assign(:current_workspace, workspace)
        |> with_path_params(%{"workspace_slug" => "matching-slug"})
        |> RequireWorkspaceMemberPlug.call([])

      assert conn.state == :unset
    end
  end

  describe "slug resolves to a different workspace" do
    test "responds 403 (token authenticated, wrong tenant)" do
      _other = workspace_fixture(slug: "other-slug")
      ours = workspace_fixture(slug: "ours-slug")

      conn =
        build_conn()
        |> assign(:current_workspace, ours)
        |> with_path_params(%{"workspace_slug" => "other-slug"})
        |> RequireWorkspaceMemberPlug.call([])

      assert conn.status == 403
    end

    test "403 body advertises `forbidden`" do
      _other = workspace_fixture(slug: "other-slug-2")
      ours = workspace_fixture(slug: "ours-slug-2")

      conn =
        build_conn()
        |> assign(:current_workspace, ours)
        |> with_path_params(%{"workspace_slug" => "other-slug-2"})
        |> RequireWorkspaceMemberPlug.call([])

      assert conn.resp_body == ~s({"error":"forbidden"})
    end
  end

  describe "slug doesn't resolve to any workspace" do
    test "responds 404" do
      ours = workspace_fixture(slug: "ours-slug-3")

      conn =
        build_conn()
        |> assign(:current_workspace, ours)
        |> with_path_params(%{"workspace_slug" => "no-such-slug"})
        |> RequireWorkspaceMemberPlug.call([])

      assert conn.status == 404
    end
  end

  defp with_path_params(conn, params) do
    %{conn | path_params: params}
  end
end
