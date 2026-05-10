defmodule HolterWeb.Web.Monitoring.MonitorNavigationTest do
  @moduledoc """
  Regression coverage for the click-monitor-card-and-land-on-detail
  flow under issue #51's RLS rollout.

  When `monitors` had RLS enabled with a strict workspace-keyed USING
  clause AND the auth-time `:require_monitor_member` hook ran an
  unwrapped `Monitoring.get_monitor/1`, the hook saw `{:error,
  :not_found}` (no tenant set yet) and redirected to `/`. The user
  bounced from /monitoring/monitor/:id back to the monitors list and
  could never reach a monitor's detail page.

  These tests pin the contract: clicking a monitor card from the
  workspace dashboard must land the user on the detail LiveView with
  the monitor's URL rendered, and a non-member must be redirected away
  from a foreign monitor's detail URL (no membership leak).
  """

  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Clicking a monitor card from the workspace dashboard" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)

      monitor =
        monitor_fixture(%{
          workspace_id: workspace.id,
          url: "https://navigation-target.local"
        })

      %{workspace: workspace, monitor: monitor}
    end

    test "the dashboard renders a navigate link pointing at the monitor detail page",
         %{conn: conn, workspace: workspace, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      detail_path = ~p"/monitoring/monitor/#{monitor.id}"

      assert has_element?(view, "a[href='#{detail_path}']")
    end

    test "the navigate link is the card-spanning anchor so the whole card is the click target",
         %{conn: conn, workspace: workspace, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      detail_path = ~p"/monitoring/monitor/#{monitor.id}"

      assert has_element?(view, "a.monitor-card-link[href='#{detail_path}']")
    end

    test "following the dashboard's monitor link mounts the detail LiveView for that monitor",
         %{conn: conn, workspace: workspace, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      detail_path = ~p"/monitoring/monitor/#{monitor.id}"

      {:ok, _detail_view, html} =
        view
        |> element("a[href='#{detail_path}']")
        |> render_click()
        |> follow_redirect(conn, detail_path)

      assert html =~ "https://navigation-target.local"
    end

    test "the detail LiveView does NOT redirect a workspace member back to the dashboard",
         %{conn: conn, monitor: monitor} do
      detail_path = ~p"/monitoring/monitor/#{monitor.id}"

      result = live(conn, detail_path)

      assert {:ok, _view, _html} = result
    end
  end

  describe "Detail-page access control under the auth hook" do
    test "a stranger (non-member) is redirected away from a foreign monitor's detail URL",
         %{conn: conn} do
      stranger_user = user_fixture()
      stranger_workspace = workspace_fixture(%{owner: stranger_user})
      foreign_monitor = monitor_fixture(%{workspace_id: stranger_workspace.id})

      detail_path = ~p"/monitoring/monitor/#{foreign_monitor.id}"

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, detail_path)
    end
  end
end
