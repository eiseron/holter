defmodule HolterWeb.Components.Monitoring.MonitorSubnavTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.MonitorSubnav

  @monitor_id "abc-123"

  @links %{
    show: "/monitoring/monitor/#{@monitor_id}",
    daily_metrics: "/monitoring/monitor/#{@monitor_id}/daily_metrics",
    logs: "/monitoring/monitor/#{@monitor_id}/logs",
    incidents: "/monitoring/monitor/#{@monitor_id}/incidents"
  }

  defp render_nav(current_page) do
    render_component(&monitor_subnav/1,
      monitor_id: @monitor_id,
      current_page: current_page
    )
  end

  defp link_hrefs(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find("a")
    |> Enum.map(&Floki.attribute(&1, "href"))
    |> List.flatten()
  end

  defp current_link_hrefs(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(~s(a[aria-current="page"]))
    |> Enum.map(&Floki.attribute(&1, "href"))
    |> List.flatten()
  end

  describe "structure" do
    for page <- [:show, :daily_metrics, :logs, :incidents, :log_detail, :incident_detail] do
      test "renders all four monitor links on the #{page} page" do
        hrefs = unquote(page) |> render_nav() |> link_hrefs()
        assert Enum.sort(hrefs) == Enum.sort(Map.values(@links))
      end
    end
  end

  describe "active link marker" do
    for {page, href} <- @links do
      test "marks the #{page} link as aria-current on the #{page} page" do
        assert current_link_hrefs(render_nav(unquote(page))) == [unquote(href)]
      end

      test "does not mark the #{page} link as aria-current on other pages" do
        for other when other != unquote(page) <- [:show, :daily_metrics, :logs, :incidents] do
          refute unquote(href) in current_link_hrefs(render_nav(other))
        end
      end
    end

    test "marks no link as aria-current on the log_detail page" do
      assert current_link_hrefs(render_nav(:log_detail)) == []
    end

    test "marks no link as aria-current on the incident_detail page" do
      assert current_link_hrefs(render_nav(:incident_detail)) == []
    end
  end

  describe "link labels" do
    test "renders Monitor Details label" do
      assert render_nav(:logs) =~ "Monitor Details"
    end

    test "renders Daily Metrics label" do
      assert render_nav(:logs) =~ "Daily Metrics"
    end

    test "renders Technical Logs label" do
      assert render_nav(:show) =~ "Technical Logs"
    end

    test "renders Incidents label" do
      assert render_nav(:logs) =~ "Incidents"
    end
  end
end
