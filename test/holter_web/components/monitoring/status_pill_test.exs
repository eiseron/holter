defmodule HolterWeb.Components.Monitoring.StatusPillTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.StatusPill

  describe "data attributes" do
    test "renders data-role=log-status" do
      html = render_component(&status_pill/1, status: :up)
      assert html =~ ~s(data-role="log-status")
    end

    test "renders data-status with status value" do
      html = render_component(&status_pill/1, status: :down)
      assert html =~ ~s(data-status="down")
    end
  end

  describe "CSS classes" do
    test "renders h-status-pill class" do
      html = render_component(&status_pill/1, status: :up)
      assert html =~ "h-status-pill"
    end

    test "renders h-status-up class for :up" do
      html = render_component(&status_pill/1, status: :up)
      assert html =~ "h-status-up"
    end

    test "renders h-status-down class for :down" do
      html = render_component(&status_pill/1, status: :down)
      assert html =~ "h-status-down"
    end

    test "renders h-status-degraded class for :degraded" do
      html = render_component(&status_pill/1, status: :degraded)
      assert html =~ "h-status-degraded"
    end
  end

  describe "label text" do
    test "shows :up uppercased" do
      html = render_component(&status_pill/1, status: :up)
      assert html =~ "UP"
    end

    test "shows :down uppercased" do
      html = render_component(&status_pill/1, status: :down)
      assert html =~ "DOWN"
    end
  end

  describe "status code" do
    test "renders status code in parentheses when provided" do
      html = render_component(&status_pill/1, status: :up, status_code: 200)
      assert html =~ "(200)"
    end

    test "does not render status code span when nil" do
      html = render_component(&status_pill/1, status: :up, status_code: nil)
      refute html =~ "("
    end
  end
end
