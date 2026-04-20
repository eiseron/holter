defmodule HolterWeb.Components.Monitoring.MonitorSubnavTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.MonitorSubnav

  @monitor_id "abc-123"
  @workspace_slug "my-workspace"

  defp render_nav(current_page) do
    render_component(&monitor_subnav/1,
      monitor_id: @monitor_id,
      workspace_slug: @workspace_slug,
      current_page: current_page
    )
  end

  describe "Dashboard link" do
    test "always renders with the correct workspace URL" do
      html = render_nav(:show)
      assert html =~ ~s(href="/monitoring/workspaces/#{@workspace_slug}/dashboard")
    end

    test "renders on nested pages (log_detail)" do
      html = render_nav(:log_detail)
      assert html =~ ~s(href="/monitoring/workspaces/#{@workspace_slug}/dashboard")
    end

    test "renders on nested pages (incident_detail)" do
      html = render_nav(:incident_detail)
      assert html =~ ~s(href="/monitoring/workspaces/#{@workspace_slug}/dashboard")
    end
  end

  describe "Monitor Details link" do
    test "is hidden on the show page" do
      html = render_nav(:show)
      refute html =~ ~s(href="/monitoring/monitor/#{@monitor_id}")
    end

    test "is visible from the logs page" do
      html = render_nav(:logs)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}")
    end

    test "is visible from the daily_metrics page" do
      html = render_nav(:daily_metrics)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}")
    end

    test "is visible from the incidents page" do
      html = render_nav(:incidents)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}")
    end

    test "is visible from the log_detail page" do
      html = render_nav(:log_detail)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}")
    end

    test "is visible from the incident_detail page" do
      html = render_nav(:incident_detail)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}")
    end
  end

  describe "Daily Metrics link" do
    test "is hidden on the daily_metrics page" do
      html = render_nav(:daily_metrics)
      refute html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/daily_metrics")
    end

    test "is visible from the show page" do
      html = render_nav(:show)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/daily_metrics")
    end

    test "is visible from the logs page" do
      html = render_nav(:logs)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/daily_metrics")
    end
  end

  describe "Technical Logs link" do
    test "is hidden on the logs page" do
      html = render_nav(:logs)
      refute html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/logs")
    end

    test "is visible from the show page" do
      html = render_nav(:show)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/logs")
    end

    test "is visible from the incidents page" do
      html = render_nav(:incidents)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/logs")
    end
  end

  describe "Incidents link" do
    test "is hidden on the incidents page" do
      html = render_nav(:incidents)
      refute html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/incidents")
    end

    test "is visible from the show page" do
      html = render_nav(:show)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/incidents")
    end

    test "is visible from the logs page" do
      html = render_nav(:logs)
      assert html =~ ~s(href="/monitoring/monitor/#{@monitor_id}/incidents")
    end
  end

  describe "link labels" do
    test "renders Dashboard label" do
      html = render_nav(:logs)
      assert html =~ "Dashboard"
    end

    test "renders Monitor Details label" do
      html = render_nav(:logs)
      assert html =~ "Monitor Details"
    end

    test "renders Daily Metrics label" do
      html = render_nav(:logs)
      assert html =~ "Daily Metrics"
    end

    test "renders Technical Logs label" do
      html = render_nav(:show)
      assert html =~ "Technical Logs"
    end

    test "renders Incidents label" do
      html = render_nav(:logs)
      assert html =~ "Incidents"
    end
  end
end
