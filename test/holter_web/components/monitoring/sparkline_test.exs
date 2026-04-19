defmodule HolterWeb.Components.Monitoring.SparklineTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.Sparkline

  defp log(latency_ms, status \\ :up) do
    %{latency_ms: latency_ms, status: status}
  end

  describe "empty state" do
    test "renders no-data message when logs is empty" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [])
      assert html =~ "No data yet"
    end

    test "renders a dashed baseline when logs is empty" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [])
      assert html =~ "stroke-dasharray"
    end

    test "does not render a sparkline path when logs is empty" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [])
      refute html =~ ~r/<path/
    end
  end

  describe "path generation" do
    test "renders a path element when logs are present" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(100)])
      assert html =~ "<path"
    end

    test "path starts at x=0 for a single log" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(100)])
      assert html =~ ~r/d="M 0,/
    end

    test "first log starts at x=0" do
      logs = [log(100), log(200), log(300)]
      html = render_component(&sparkline/1, monitor_id: "abc", logs: logs)
      assert html =~ "0,"
    end

    test "second log is at x=10" do
      logs = [log(100), log(200), log(300)]
      html = render_component(&sparkline/1, monitor_id: "abc", logs: logs)
      assert html =~ "10,"
    end

    test "third log is at x=20" do
      logs = [log(100), log(200), log(300)]
      html = render_component(&sparkline/1, monitor_id: "abc", logs: logs)
      assert html =~ "20,"
    end

    test "oldest log (low latency) is rendered at x=0 when passed newest-first" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(900), log(100)])
      assert html =~ "0,64.0"
    end

    test "newest log (high latency) is rendered at x=10 when passed newest-first" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(900), log(100)])
      assert html =~ "10,16.0"
    end
  end

  describe "y normalization" do
    test "nil latency renders at y=75 (baseline)" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(nil)])
      assert html =~ "0,75"
    end

    test "latency 0 renders near y=70" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(0)])
      assert html =~ "0,70"
    end

    test "latency 1000 renders near y=10" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(1000)])
      assert html =~ "0,10"
    end

    test "latency above 1000 is clamped to 1000 — same y as 1000ms" do
      html_capped = render_component(&sparkline/1, monitor_id: "abc", logs: [log(5000)])
      html_max = render_component(&sparkline/1, monitor_id: "abc", logs: [log(1000)])

      y_capped = Regex.run(~r/d="M 0,([^"]+)"/, html_capped) |> List.last()
      y_max = Regex.run(~r/d="M 0,([^"]+)"/, html_max) |> List.last()

      assert y_capped == y_max
    end
  end

  describe "error markers" do
    test "does not render an error marker for status :up" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(100, :up)])
      refute html =~ "sparkline-error-marker"
    end

    test "renders an error marker for status :down" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(100, :down)])
      assert html =~ "sparkline-error-marker"
    end

    test "renders an error marker for status :degraded" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(100, :degraded)])
      assert html =~ "sparkline-error-marker"
    end

    test "renders an error marker for status :compromised" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(100, :compromised)])
      assert html =~ "sparkline-error-marker"
    end

    test "renders an error marker for status :unknown" do
      html = render_component(&sparkline/1, monitor_id: "abc", logs: [log(100, :unknown)])
      assert html =~ "sparkline-error-marker"
    end

    test "renders markers only for non-up entries in a mixed list" do
      logs = [log(100, :up), log(200, :down), log(300, :up)]
      html = render_component(&sparkline/1, monitor_id: "abc", logs: logs)

      marker_count =
        html
        |> String.split("sparkline-error-marker")
        |> length()
        |> Kernel.-(1)

      assert marker_count == 1
    end
  end

  describe "container" do
    test "uses monitor_id in the container id attribute" do
      html = render_component(&sparkline/1, monitor_id: "monitor-xyz", logs: [])
      assert html =~ ~s(id="sparkline-monitor-xyz")
    end
  end
end
