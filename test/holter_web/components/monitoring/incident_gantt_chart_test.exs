defmodule HolterWeb.Components.Monitoring.IncidentGanttChartTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.IncidentGanttChart

  defp gantt_data_with_bars(bars) do
    %{bars: bars, x_labels: [%{x: 40.0, label: "01/01"}], has_incidents: true}
  end

  defp resolved_bar do
    %{id: "r1", x: 80.0, width: 200.0, lane: 0, fill: "var(--color-status-down)", open?: false}
  end

  defp open_bar do
    %{id: "o1", x: 80.0, width: 200.0, lane: 0, fill: "var(--color-status-down)", open?: true}
  end

  describe "visibility" do
    test "does not render when has_incidents is false" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: %{bars: [], x_labels: [], has_incidents: false}
        )

      refute html =~ "incident-gantt-container"
    end

    test "renders when has_incidents is true" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars([resolved_bar()])
        )

      assert html =~ "incident-gantt-container"
    end
  end

  describe "bar rendering" do
    test "renders a rect element for each bar" do
      bars = [resolved_bar(), open_bar()]

      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars(bars)
        )

      rect_count =
        html
        |> String.split("<rect")
        |> length()
        |> Kernel.-(1)

      assert rect_count == 2
    end

    test "renders a dashed edge line for an open incident bar" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars([open_bar()])
        )

      assert html =~ "gantt-bar-open-edge"
    end

    test "does not render a dashed edge line for a resolved incident bar" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars([resolved_bar()])
        )

      refute html =~ "gantt-bar-open-edge"
    end
  end

  describe "legend" do
    test "renders Downtime legend label" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars([resolved_bar()])
        )

      assert html =~ "Downtime"
    end

    test "renders Defacement legend label" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars([resolved_bar()])
        )

      assert html =~ "Defacement"
    end

    test "renders SSL Expiry legend label" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars([resolved_bar()])
        )

      assert html =~ "SSL Expiry"
    end

    test "renders Open legend label" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "m1",
          gantt_data: gantt_data_with_bars([resolved_bar()])
        )

      assert html =~ "Open"
    end
  end

  describe "container id" do
    test "uses monitor_id in the container id attribute" do
      html =
        render_component(&incident_gantt_chart/1,
          monitor_id: "monitor-abc",
          gantt_data: gantt_data_with_bars([resolved_bar()])
        )

      assert html =~ ~s(id="incident-gantt-monitor-abc")
    end
  end
end
