defmodule HolterWeb.Web.Admin.WorkspacesLive.ShowTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  alias HolterWeb.Web.Admin.WorkspacesLive.Show

  describe "role_label/1" do
    test "labels :owner", do: assert(Show.role_label(:owner) == "Owner")
    test "labels :admin", do: assert(Show.role_label(:admin) == "Admin")
    test "labels :member", do: assert(Show.role_label(:member) == "Member")
  end

  describe "user_status_label/1" do
    test "labels :pending_verification" do
      assert Show.user_status_label(:pending_verification) == "Pending verification"
    end

    test "labels :active", do: assert(Show.user_status_label(:active) == "Active")

    test "labels :pending_billing" do
      assert Show.user_status_label(:pending_billing) == "Pending billing"
    end

    test "labels :banned", do: assert(Show.user_status_label(:banned) == "Banned")
  end

  describe "monitor_state_label/1" do
    test "labels :active", do: assert(Show.monitor_state_label(:active) == "Active")
    test "labels :paused", do: assert(Show.monitor_state_label(:paused) == "Paused")
    test "labels :archived", do: assert(Show.monitor_state_label(:archived) == "Archived")
  end

  describe "health_label/1" do
    test "labels :up", do: assert(Show.health_label(:up) == "Up")
    test "labels :down", do: assert(Show.health_label(:down) == "Down")
    test "labels :degraded", do: assert(Show.health_label(:degraded) == "Degraded")
    test "labels :compromised", do: assert(Show.health_label(:compromised) == "Compromised")
    test "labels :unknown", do: assert(Show.health_label(:unknown) == "Unknown")
  end

  describe "auth gate" do
    test "guest is redirected to login", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()

      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/admin/workspaces/#{workspace.id}")
    end

    test "signed-in non-admin is redirected to /", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      %{user: viewer} = verified_user_fixture()
      conn = log_in_user(conn, viewer)

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/workspaces/#{workspace.id}")
    end
  end

  describe "as admin" do
    setup %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      %{conn: log_in_user(conn, admin_user), admin_user: admin_user}
    end

    test "renders the workspace name as h1", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ workspace.name
    end

    test "renders the workspace slug", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ workspace.slug
    end

    test "renders the back link to the listing", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ ~s|href="/admin/workspaces"|
    end

    test "lists the workspace owner in the members table", %{conn: conn} do
      %{user: owner, workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ owner.email
    end

    test "links each member email to /admin/users/:id", %{conn: conn} do
      %{user: owner, workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ ~s|href="/admin/users/#{owner.id}"|
    end

    test "renders the empty monitors state", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ "Workspace has no monitors"
    end

    test "renders monitors that belong to the workspace", %{conn: conn} do
      %{user: owner, workspace: workspace} = verified_user_fixture()

      monitor =
        Holter.MonitoringFixtures.monitor_fixture(
          owner: owner,
          workspace: workspace,
          url: "https://uniq-monitor.example.com",
          interval_seconds: 600
        )

      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ monitor.url
    end

    test "renders the monitoring plan card with the max_monitors quota", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ "Monitoring plan"
      assert html =~ "Max monitors"
    end

    test "renders the delivery plan card with the max_channels quota", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ "Delivery plan"
      assert html =~ "Max channels"
    end

    test "renders the empty audit state when no rows exist", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ "No admin actions"
    end

    test "renders an audit row when one exists for the workspace", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()

      audit_log_fixture(%{
        resource: "Workspace:" <> workspace.id,
        action: "unique_ws_action_xyz"
      })

      {:ok, _view, html} = live(conn, ~p"/admin/workspaces/#{workspace.id}")
      assert html =~ "unique_ws_action_xyz"
    end

    test "raises Ecto.NoResultsError on unknown workspace id", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/admin/workspaces/00000000-0000-0000-0000-000000000000")
      end
    end

    test "listing links workspace name to the detail page", %{conn: conn} do
      %{workspace: workspace} = verified_user_fixture()
      {:ok, _view, html} = live(conn, ~p"/admin/workspaces")
      assert html =~ ~s|href="/admin/workspaces/#{workspace.id}"|
    end
  end
end
