defmodule HolterWeb.Web.Admin.AuditLogLiveTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  describe "auth gate" do
    test "guest is redirected to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/identity/login"}}} = live(conn, ~p"/admin/audit-log")
    end

    test "signed-in non-admin is redirected to /", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      conn = log_in_user(conn, user)
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/audit-log")
    end
  end

  describe "as admin" do
    setup %{conn: conn} do
      %{user: user} = verified_user_fixture()
      _admin = admin_fixture(%{user: user})
      %{conn: log_in_user(conn, user)}
    end

    test "renders the heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/audit-log")
      assert html =~ "Audit log"
    end

    test "renders an empty state when no rows exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/audit-log")
      assert html =~ "No audit entries"
    end

    test "renders a row when one exists", %{conn: conn} do
      audit_log_fixture(%{action: "unique_action_listing", resource: "User:abc"})
      {:ok, _view, html} = live(conn, ~p"/admin/audit-log")
      assert html =~ "unique_action_listing"
    end

    test "filters by action via the form", %{conn: conn} do
      target = audit_log_fixture(%{action: "target_action_x", resource: "User:1"})
      _decoy = audit_log_fixture(%{action: "decoy_action_y", resource: "User:2"})

      {:ok, view, _html} = live(conn, ~p"/admin/audit-log")

      html =
        view
        |> form("#audit-log-filters", filters: %{action: "target_action_x"})
        |> render_change()

      assert html =~ target.action
      refute html =~ "decoy_action_y"
    end

    test "filters by resource via the form", %{conn: conn} do
      target = audit_log_fixture(%{action: "act1", resource: "User:target-resource-id"})
      _decoy = audit_log_fixture(%{action: "act2", resource: "User:decoy-resource-id"})

      {:ok, view, _html} = live(conn, ~p"/admin/audit-log")

      html =
        view
        |> form("#audit-log-filters", filters: %{resource: "User:target-resource-id"})
        |> render_change()

      assert html =~ target.resource
      refute html =~ "User:decoy-resource-id"
    end

    test "renders a diff details element when the row has a non-empty diff", %{conn: conn} do
      audit_log_fixture(%{action: "act", resource: "User:1", diff: %{"key" => "value"}})
      {:ok, _view, html} = live(conn, ~p"/admin/audit-log")
      assert html =~ "<details"
      assert html =~ "key"
    end

    test "renders an em-dash for an empty diff", %{conn: conn} do
      audit_log_fixture(%{action: "empty_diff_action", resource: "User:1", diff: %{}})
      {:ok, _view, html} = live(conn, ~p"/admin/audit-log")
      assert html =~ "—"
    end

    test "marks the Audit log sidebar link as active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/audit-log")

      assert html =~
               ~r/h-sidebar-link[^"]*h-sidebar-link--active[^"]*"[^>]*>\s*<span[^>]*>Audit log/
    end
  end
end
