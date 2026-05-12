defmodule HolterWeb.Web.Admin.UsersLiveTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  alias Holter.Repo

  describe "auth gate" do
    test "guest is redirected to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/identity/login"}}} = live(conn, ~p"/admin/users")
    end

    test "signed-in non-admin is redirected to /", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
    end
  end

  describe "as admin" do
    setup %{conn: conn} do
      %{user: user} = verified_user_fixture()
      _admin = admin_fixture(%{user: user})
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the Users heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ "Users"
    end

    test "lists existing users by email", %{conn: conn, user: admin_user} do
      target = user_fixture(%{email: "listing-target@h.test"})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ target.email
      assert html =~ admin_user.email
    end

    test "filters by email substring via the form", %{conn: conn} do
      target =
        user_fixture(%{email: "filter-needle-#{System.unique_integer([:positive])}@h.test"})

      _decoy = user_fixture(%{email: "decoy-#{System.unique_integer([:positive])}@h.test"})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html =
        view
        |> form("#users-filters", filters: %{email: "filter-needle"})
        |> render_change()

      assert html =~ target.email
    end

    test "filters by status via the form", %{conn: conn} do
      banned = user_fixture()

      banned
      |> Ecto.Changeset.change(onboarding_status: :banned)
      |> Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html =
        view
        |> form("#users-filters", filters: %{status: "banned"})
        |> render_change()

      assert html =~ banned.email
    end

    test "renders the empty state when no users match", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/users?email=zzzzz-never-matches-zzzzz")
      assert html =~ "No users match"
    end

    test "renders the status tag for banned users", %{conn: conn} do
      banned = user_fixture()

      banned
      |> Ecto.Changeset.change(onboarding_status: :banned)
      |> Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/admin/users?status=banned")
      assert html =~ "h-status-tag--banned"
    end

    test "marks the Users sidebar link as active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ ~r/h-sidebar-link[^"]*h-sidebar-link--active[^"]*"[^>]*>\s*<span[^>]*>Users/
    end
  end
end
