defmodule HolterWeb.Web.Admin.WorkspacesLiveTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  describe "auth gate" do
    test "guest is redirected to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/admin/workspaces")
    end

    test "signed-in non-admin is redirected to /", %{conn: conn} do
      %{user: viewer} = verified_user_fixture()
      conn = log_in_user(conn, viewer)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/workspaces")
    end
  end

  describe "as admin" do
    setup %{conn: conn} do
      %{user: admin_user, workspace: workspace} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      %{conn: log_in_user(conn, admin_user), admin_user: admin_user, workspace: workspace}
    end

    test "renders the page heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces")
      assert html =~ "Workspaces"
    end

    test "shows workspaces in the table", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces")
      assert html =~ workspace.slug
    end

    test "shows the workspace name", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces")
      assert html =~ workspace.name
    end

    test "shows the total count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces")
      assert html =~ "Total:"
    end

    test "filter by name narrows results", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/admin/workspaces")

      html =
        view
        |> form("#workspaces-filters", filters: %{name: workspace.name})
        |> render_change()

      assert html =~ workspace.slug
    end

    test "filter with no match shows empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/workspaces")

      html =
        view
        |> form("#workspaces-filters", filters: %{name: "zzz_nonexistent_zzz"})
        |> render_change()

      assert html =~ "No workspaces match"
    end

    test "sidebar workspaces link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces")
      assert html =~ ~r/h-sidebar-link--active.*Workspaces/s
    end
  end
end
