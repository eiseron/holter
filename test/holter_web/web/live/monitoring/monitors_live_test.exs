defmodule HolterWeb.Web.Monitoring.MonitorsLiveTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Monitoring

  describe "Dashboard mount" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)
      %{workspace: workspace}
    end

    test "Given a valid workspace slug, when mounted, then the page renders",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "Monitors"
    end

    test "Given a workspace with no monitors, when mounted, then the empty state is shown",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "No assets monitored"
    end

    test "Given a workspace with monitors, when mounted, then monitor URLs are listed",
         %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id, url: "https://listed.local"})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "https://listed.local"
    end

    test "Given a workspace below quota, when mounted, then the new monitor button is enabled",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      refute html =~ "disabled"
    end

    test "Given a workspace at quota, when mounted, then the new monitor button is disabled",
         %{conn: conn, workspace: workspace} do
      for _ <- 1..workspace.max_monitors do
        monitor_fixture(%{workspace_id: workspace.id})
      end

      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "disabled"
    end

    test "Bug simulation: Static Interval Display (fails if bug exists)",
         %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id, interval_seconds: 900})

      {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "900s"
      refute html =~ "600s"
    end
  end

  describe "Dashboard ranking order" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)
      %{workspace: workspace}
    end

    test "Given monitors with mixed health, when mounted, then DOWN monitors appear before UP",
         %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id, url: "https://up.local", health_status: :up})

      monitor_fixture(%{
        workspace_id: workspace.id,
        url: "https://down.local",
        health_status: :down
      })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      pos_down = :binary.match(html, "https://down.local") |> elem(0)
      pos_up = :binary.match(html, "https://up.local") |> elem(0)
      assert pos_down < pos_up
    end

    test "Given an active and a paused monitor, when mounted, then paused monitor appears last",
         %{conn: conn, workspace: workspace} do
      monitor_fixture(%{
        workspace_id: workspace.id,
        url: "https://paused.local",
        logical_state: :paused
      })

      monitor_fixture(%{
        workspace_id: workspace.id,
        url: "https://active.local",
        logical_state: :active
      })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      pos_active = :binary.match(html, "https://active.local") |> elem(0)
      pos_paused = :binary.match(html, "https://paused.local") |> elem(0)
      assert pos_active < pos_paused
    end
  end

  describe "Dashboard real-time updates" do
    test "Given a new monitor is created, when PubSub event fires, then new monitor appears",
         %{conn: conn, current_user: user} do
      workspace = workspace_fixture_for(user)

      {:ok, lv, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      monitor_fixture(%{workspace_id: workspace.id, url: "https://realtime.local"})

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:monitors",
        {:monitor_created, nil}
      )

      assert has_element?(lv, "[data-role='monitor-url']", "https://realtime.local")
    end

    test "Given a monitor is deleted, when PubSub event fires, then monitor disappears",
         %{conn: conn, current_user: user} do
      workspace = workspace_fixture_for(user)
      monitor = monitor_fixture(%{workspace_id: workspace.id, url: "https://gone.local"})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert has_element?(lv, "[data-role='monitor-url']", "https://gone.local")

      Monitoring.delete_monitor(monitor)

      Phoenix.PubSub.broadcast(
        Holter.PubSub,
        "monitoring:monitors",
        {:monitor_deleted, nil}
      )

      refute has_element?(lv, "[data-role='monitor-url']", "https://gone.local")
    end
  end

  describe "Dashboard terminology" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)
      %{workspace: workspace}
    end

    test "Given a monitor with 1 incident, when mounted, then it shows '1 incident'",
         %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id, open_incidents_count: 1})
      incident_fixture(%{monitor_id: monitor.id})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "1 incident"
    end

    test "Given a monitor with multiple incidents, when mounted, then it shows 'X incidents'",
         %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id, open_incidents_count: 2})
      incident_fixture(%{monitor_id: monitor.id})
      incident_fixture(%{monitor_id: monitor.id, type: :ssl_expiry})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "2 incidents"
    end
  end

  describe "Workspace layout structure (regression #30)" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)
      %{workspace: workspace}
    end

    test "wraps the page in div.h-workspace-layout so the shell can be height-constrained",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert has_element?(view, "div.h-workspace-layout")
    end

    test "renders the sidebar as nav.h-workspace-sidebar so it can scroll independently of main",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assert has_element?(view, "nav.h-workspace-sidebar")
    end
  end
end
