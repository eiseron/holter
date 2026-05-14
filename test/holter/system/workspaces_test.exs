defmodule Holter.System.WorkspacesTest do
  use Holter.DataCase, async: true

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
end
