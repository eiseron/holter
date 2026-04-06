defmodule HolterWeb.Web.Monitoring.DashboardRankingTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Holter.Monitoring

  describe "Tactical Dashboard Ranking (Scenario 43)" do
    setup do
      workspace = workspace_fixture(slug: "tactical-ws")
      %{workspace: workspace}
    end

    test "Given multiple monitors, when displayed in dashboard, then DOWN monitors appear before UP monitors",
         %{conn: conn, workspace: workspace} do
      monitor_up =
        monitor_fixture(workspace_id: workspace.id, url: "https://up.local", health_status: :up)

      monitor_down =
        monitor_fixture(
          workspace_id: workspace.id,
          url: "https://down.local",
          health_status: :down
        )

      {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/dashboard")

      matches = Regex.scan(~r/https:\/\/[a-z0-9.-]+/, html) |> List.flatten()

      assert Enum.find_index(matches, &(&1 == monitor_down.url)) <
               Enum.find_index(matches, &(&1 == monitor_up.url))
    end

    test "Given an UP monitor, when it transitions to DOWN, then it automatically moves to the top of the list",
         %{conn: conn, workspace: workspace} do
      monitor_1 =
        monitor_fixture(
          workspace_id: workspace.id,
          url: "https://site-1.local",
          health_status: :up
        )

      Process.sleep(1001)

      monitor_2 =
        monitor_fixture(
          workspace_id: workspace.id,
          url: "https://site-2.local",
          health_status: :up
        )

      {:ok, view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/dashboard")

      matches_initial = Regex.scan(~r/https:\/\/[a-z0-9.-]+/, html) |> List.flatten()
      assert List.first(matches_initial) == monitor_2.url

      {:ok, _} = Monitoring.update_monitor(monitor_1, %{health_status: :down})

      html_updated = render(view)
      matches_after = Regex.scan(~r/https:\/\/[a-z0-9.-]+/, html_updated) |> List.flatten()

      assert List.first(matches_after) == monitor_1.url
    end

    test "Given multiple failing monitors, when displayed, then they are ordered by severity (DOWN > DEGRADED)",
         %{conn: conn, workspace: workspace} do
      _monitor_up =
        monitor_fixture(workspace_id: workspace.id, url: "https://up.local", health_status: :up)

      monitor_degraded =
        monitor_fixture(
          workspace_id: workspace.id,
          url: "https://degraded.local",
          health_status: :degraded
        )

      monitor_down =
        monitor_fixture(
          workspace_id: workspace.id,
          url: "https://down.local",
          health_status: :down
        )

      {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/dashboard")

      matches = Regex.scan(~r/https:\/\/[a-z\.]+/, html) |> List.flatten()

      down_idx = Enum.find_index(matches, &(&1 == monitor_down.url))
      degraded_idx = Enum.find_index(matches, &(&1 == monitor_degraded.url))

      assert down_idx < degraded_idx
    end
  end
end
