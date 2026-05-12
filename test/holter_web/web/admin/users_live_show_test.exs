defmodule HolterWeb.Web.Admin.UsersLive.ShowTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  alias Holter.Repo

  describe "auth gate" do
    test "guest is redirected to login", %{conn: conn} do
      %{user: target} = verified_user_fixture()

      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/admin/users/#{target.id}")
    end

    test "signed-in non-admin is redirected to /", %{conn: conn} do
      %{user: target} = verified_user_fixture()
      %{user: viewer} = verified_user_fixture()
      conn = log_in_user(conn, viewer)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users/#{target.id}")
    end
  end

  describe "as admin" do
    setup %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      %{conn: log_in_user(conn, admin_user), admin_user: admin_user}
    end

    test "renders the target user's email as h1", %{conn: conn} do
      %{user: target} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ target.email
    end

    test "renders the status tag matching the target's onboarding_status", %{conn: conn} do
      %{user: target} = verified_user_fixture()

      target
      |> Ecto.Changeset.change(onboarding_status: :banned)
      |> Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ "h-status-tag--banned"
    end

    test "renders the back link to the listing", %{conn: conn} do
      %{user: target} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ ~s|href="/admin/users"|
    end

    test "lists workspaces the user belongs to", %{conn: conn} do
      %{user: target, workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ workspace.slug
    end

    test "renders the audit log section heading", %{conn: conn} do
      %{user: target} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ "Audit log"
    end

    test "renders the empty audit state when no rows exist", %{conn: conn} do
      %{user: target} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ "No admin actions"
    end

    test "renders an audit row when one exists for the user", %{conn: conn} do
      %{user: target} = verified_user_fixture()
      audit_log_fixture(%{resource: "User:" <> target.id, action: "unique_action_xyz"})
      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ "unique_action_xyz"
    end

    test "shows disabled placeholders for impersonation, plan grant and ban", %{conn: conn} do
      %{user: target} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")
      assert html =~ "Sign in as this user"
      assert html =~ "Grant manual plan"
      assert html =~ "Ban user"
      assert html =~ ~r/disabled/
    end

    test "404s on an unknown user id", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/admin/users/00000000-0000-0000-0000-000000000000")
      end
    end
  end
end
