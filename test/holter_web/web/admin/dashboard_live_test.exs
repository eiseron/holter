defmodule HolterWeb.Web.Admin.DashboardLiveTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  describe "guest" do
    test "is redirected to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/identity/login"}}} = live(conn, ~p"/admin")
    end
  end

  describe "signed-in non-admin user" do
    setup %{conn: conn} do
      %{user: user} = verified_user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "is redirected to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end

    test "does not see the dashboard heading", %{conn: conn} do
      assert {:error, _} = live(conn, ~p"/admin")
    end
  end

  describe "signed-in admin" do
    setup %{conn: conn} do
      %{user: user} = verified_user_fixture()
      _admin = admin_fixture(%{user: user})
      %{conn: log_in_user(conn, user), user: user}
    end

    test "reaches the dashboard", %{conn: conn} do
      assert {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Admin Panel"
    end

    test "sees their own email in the topbar", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ user.email
    end

    test "sees the 'God mode' label in the topbar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "God mode"
    end

    test "sees the Users placeholder card", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Users"
    end

    test "sees the Audit log placeholder card", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Audit log"
    end

    test "sees the Exit admin link pointing to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")
      assert view |> element("a.h-sidebar-link", "Exit admin") |> render() =~ ~s|href="/"|
    end
  end
end
