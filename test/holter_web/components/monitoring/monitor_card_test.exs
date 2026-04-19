defmodule HolterWeb.Components.Monitoring.MonitorCardTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.MonitorCard

  defp monitor_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        id: "abc12345-0000-0000-0000-000000000000",
        url: "https://example.com",
        method: :get,
        interval_seconds: 60,
        health_status: :up,
        logical_state: :active,
        logs: []
      },
      overrides
    )
  end

  describe "monitor info" do
    test "renders monitor URL" do
      html = render_component(&monitor_card/1, monitor: monitor_attrs(), detail_url: "/details")
      assert html =~ "https://example.com"
    end

    test "renders method uppercased" do
      html = render_component(&monitor_card/1, monitor: monitor_attrs(), detail_url: "/details")
      assert html =~ "GET"
    end

    test "renders interval in seconds" do
      html = render_component(&monitor_card/1, monitor: monitor_attrs(), detail_url: "/details")
      assert html =~ "60s"
    end

    test "renders first 8 characters of monitor ID" do
      html = render_component(&monitor_card/1, monitor: monitor_attrs(), detail_url: "/details")
      assert html =~ "abc12345"
    end
  end

  describe "navigation" do
    test "renders link to detail_url" do
      html = render_component(&monitor_card/1, monitor: monitor_attrs(), detail_url: "/my/detail")
      assert html =~ "/my/detail"
    end
  end

  describe "embedded components" do
    test "renders sparkline container for monitor id" do
      monitor = monitor_attrs(%{id: "spark-id-0000-0000-0000-000000000000"})
      html = render_component(&monitor_card/1, monitor: monitor, detail_url: "/d")
      assert html =~ "sparkline-spark-id-0000-0000-0000-000000000000"
    end

    test "renders health badge" do
      html = render_component(&monitor_card/1, monitor: monitor_attrs(), detail_url: "/d")
      assert html =~ "h-health-pulse-badge"
    end
  end
end
