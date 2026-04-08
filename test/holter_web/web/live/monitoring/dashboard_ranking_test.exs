defmodule HolterWeb.Web.Monitoring.DashboardRankingTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Holter.Monitoring

  describe "Tactical Dashboard Ranking (Scenario 43)" do
    setup do
      workspace = workspace_fixture(slug: "tactical-ws")
      %{workspace: workspace}
    end

    defp extract_monitor_urls(view_or_html) do
      html = if is_binary(view_or_html), do: view_or_html, else: render(view_or_html)

      html
      |> Floki.parse_document!()
      |> Floki.find("[data-role='monitor-url']")
      |> Enum.map(&Floki.text/1)
      |> Enum.map(&String.trim/1)
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

      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/dashboard")

      urls = extract_monitor_urls(view)

      assert Enum.find_index(urls, &(&1 == monitor_down.url)) <
               Enum.find_index(urls, &(&1 == monitor_up.url))
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

      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/dashboard")

      urls_initial = extract_monitor_urls(view)
      assert List.first(urls_initial) == monitor_2.url

      {:ok, _} = Monitoring.update_monitor(monitor_1, %{health_status: :down})

      urls_updated = extract_monitor_urls(view)
      assert List.first(urls_updated) == monitor_1.url
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

      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/dashboard")

      urls = extract_monitor_urls(view)

      down_idx = Enum.find_index(urls, &(&1 == monitor_down.url))
      degraded_idx = Enum.find_index(urls, &(&1 == monitor_degraded.url))

      assert down_idx < degraded_idx
    end
  end
end
