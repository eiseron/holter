defmodule HolterWeb.Web.Monitoring.MonitorNavigationRLSTest do
  @moduledoc """
  Regression coverage for the click-monitor → detail navigation flow,
  exercised under the `holter_app` Postgres role so the RLS policy on
  `monitors` is actually enforced (the default sandbox runs as
  `postgres` superuser and would silently bypass it).

  These tests pin the contract that production cares about:

    * The auth hook `:require_monitor_member` resolves the monitor —
      without this, the user bounces back to `/`.
    * The detail LiveView's `mount/3` does NOT re-fetch the monitor
      under RLS — it must use the resolved struct from the hook, or
      stamp the workspace explicitly. Refetching unstamped raises
      `Ecto.NoResultsError` in production.
    * The same applies to the `/logs`, `/incidents`, and
      `/daily_metrics` detail pages.
  """

  use HolterWeb.RLSConnCase

  import Phoenix.LiveViewTest

  describe "Detail pages under holter_app role with RLS enforced" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)

      monitor =
        monitor_fixture(%{
          workspace_id: workspace.id,
          url: "https://rls-target.local"
        })

      setup_app_role()

      %{workspace: workspace, monitor: monitor}
    end

    test "/monitoring/monitor/:id mounts the detail LiveView without raising NoResultsError",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "https://rls-target.local"
    end

    test "/monitoring/monitor/:id/logs mounts under the monitor without raising",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      assert html =~ "https://rls-target.local"
    end

    test "/monitoring/monitor/:id/incidents mounts under the monitor without raising",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents")

      assert html =~ "https://rls-target.local"
    end

    test "/monitoring/monitor/:id/daily_metrics mounts under the monitor without raising",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/daily_metrics")

      assert html =~ "https://rls-target.local"
    end

    test "/monitoring/workspaces/:slug/monitors lists the monitor under RLS",
         %{conn: conn, workspace: workspace, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ monitor.url
    end
  end

  describe "Cross-tenant access is blocked under RLS" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)

      stranger = user_fixture()
      stranger_workspace = workspace_fixture(%{owner: stranger})
      foreign_monitor = monitor_fixture(%{workspace_id: stranger_workspace.id})

      setup_app_role()

      %{workspace: workspace, foreign_monitor: foreign_monitor}
    end

    test "the auth hook redirects when accessing a foreign monitor's detail URL",
         %{conn: conn, foreign_monitor: foreign_monitor} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/monitoring/monitor/#{foreign_monitor.id}")
    end
  end
end
