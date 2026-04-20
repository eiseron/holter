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
        interval_seconds: 30,
        health_status: :up,
        logical_state: :active,
        logs: [],
        open_incidents_count: 0
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
      assert html =~ "30s"
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

  describe "open incidents counter" do
    test "renders open incidents badge when count is greater than zero" do
      html =
        render_component(&monitor_card/1,
          monitor: monitor_attrs(%{open_incidents_count: 2}),
          detail_url: "/d"
        )

      assert html =~ ~s(data-role="open-incidents-count")
    end

    test "renders singular 'incident' when count is exactly one" do
      html =
        render_component(&monitor_card/1,
          monitor: monitor_attrs(%{open_incidents_count: 1}),
          detail_url: "/d"
        )

      assert html =~ "1 incident"
    end

    test "renders the open incident count number in the badge" do
      html =
        render_component(&monitor_card/1,
          monitor: monitor_attrs(%{open_incidents_count: 2}),
          detail_url: "/d"
        )

      assert html =~ "2 incidents"
    end

    test "does not render open incidents badge when count is zero" do
      html =
        render_component(&monitor_card/1,
          monitor: monitor_attrs(%{open_incidents_count: 0}),
          detail_url: "/d"
        )

      refute html =~ ~s(data-role="open-incidents-count")
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
