defmodule HolterWeb.Components.Monitoring.HealthBadgeTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.HealthBadge

  describe "container" do
    test "renders h-health-pulse-badge class" do
      html = render_component(&health_badge/1, status: :up)
      assert html =~ "h-health-pulse-badge"
    end
  end

  describe "active state" do
    test "renders :up status uppercased" do
      html = render_component(&health_badge/1, status: :up)
      assert html =~ "UP"
    end

    test "renders :down status uppercased" do
      html = render_component(&health_badge/1, status: :down)
      assert html =~ "DOWN"
    end

    test "renders :degraded status uppercased" do
      html = render_component(&health_badge/1, status: :degraded)
      assert html =~ "DEGRADED"
    end

    test "renders :compromised status uppercased" do
      html = render_component(&health_badge/1, status: :compromised)
      assert html =~ "COMPROMISED"
    end

    test "renders :unknown status uppercased" do
      html = render_component(&health_badge/1, status: :unknown)
      assert html =~ "UNKNOWN"
    end

    test "applies h-status-up CSS class for :up status" do
      html = render_component(&health_badge/1, status: :up)
      assert html =~ "h-status-up"
    end

    test "applies h-status-down CSS class for :down status" do
      html = render_component(&health_badge/1, status: :down)
      assert html =~ "h-status-down"
    end

    test "renders pulse-dot when active" do
      html = render_component(&health_badge/1, status: :up, logical_state: :active)
      assert html =~ "pulse-dot"
    end
  end

  describe "paused state" do
    test "renders PAUSED label" do
      html = render_component(&health_badge/1, status: :up, logical_state: :paused)
      assert html =~ "PAUSED"
    end

    test "applies h-status-paused CSS class" do
      html = render_component(&health_badge/1, status: :up, logical_state: :paused)
      assert html =~ "h-status-paused"
    end

    test "renders pause-icon when paused" do
      html = render_component(&health_badge/1, status: :up, logical_state: :paused)
      assert html =~ "pause-icon"
    end

    test "does not render pulse-dot when paused" do
      html = render_component(&health_badge/1, status: :up, logical_state: :paused)
      refute html =~ "pulse-dot"
    end
  end
end
