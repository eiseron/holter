defmodule HolterWeb.Components.ChartUtilsTest do
  use ExUnit.Case, async: true

  alias HolterWeb.Components.ChartUtils

  describe "map_x/3" do
    test "maps the minimum timestamp to label_left" do
      min_ts = 1_000_000
      max_ts = 1_001_000
      dt = DateTime.from_unix!(min_ts)
      result = ChartUtils.map_x(dt, {min_ts, max_ts}, {40, 800})
      assert_in_delta result, 40.0, 0.01
    end

    test "maps the maximum timestamp to svg_width" do
      min_ts = 1_000_000
      max_ts = 1_001_000
      dt = DateTime.from_unix!(max_ts)
      result = ChartUtils.map_x(dt, {min_ts, max_ts}, {40, 800})
      assert_in_delta result, 800.0, 0.01
    end

    test "maps a midpoint timestamp to the center of the chart area" do
      min_ts = 1_000_000
      max_ts = 1_002_000
      mid_ts = 1_001_000
      dt = DateTime.from_unix!(mid_ts)
      result = ChartUtils.map_x(dt, {min_ts, max_ts}, {40, 840})
      assert_in_delta result, 440.0, 0.01
    end
  end

  describe "derive_max_value/3" do
    test "returns 0 for empty list" do
      assert ChartUtils.derive_max_value([], :latency_ms, 5000) == 0
    end

    test "returns max value capped by cap" do
      items = [%{latency_ms: 100}, %{latency_ms: 300}, %{latency_ms: 200}]
      assert ChartUtils.derive_max_value(items, :latency_ms, 5000) == 300
    end

    test "caps to the given cap value" do
      items = [%{latency_ms: 10_000}, %{latency_ms: 500}]
      assert ChartUtils.derive_max_value(items, :latency_ms, 5000) == 5000
    end

    test "ignores nil values" do
      items = [%{latency_ms: nil}, %{latency_ms: 200}, %{latency_ms: nil}]
      assert ChartUtils.derive_max_value(items, :latency_ms, 5000) == 200
    end

    test "returns 0 when all values are nil" do
      items = [%{latency_ms: nil}, %{latency_ms: nil}]
      assert ChartUtils.derive_max_value(items, :latency_ms, 5000) == 0
    end

    test "uses the given field name" do
      items = [%{avg_latency_ms: 400}, %{avg_latency_ms: 250}]
      assert ChartUtils.derive_max_value(items, :avg_latency_ms, 5000) == 400
    end
  end

  describe "normalize_y/3" do
    test "returns y_bottom for nil value" do
      assert ChartUtils.normalize_y(nil, 1000, {100, 10, 5000}) == 100.0
    end

    test "returns y_bottom for max=0 (falls back via cap)" do
      assert ChartUtils.normalize_y(0, 0, {100, 10, 5000}) == 100.0
    end

    test "returns y_top for value equal to max" do
      result = ChartUtils.normalize_y(1000, 1000, {100, 10, 1000})
      assert_in_delta result, 10.0, 0.01
    end

    test "returns y_bottom for value equal to 0" do
      result = ChartUtils.normalize_y(0, 1000, {100, 10, 5000})
      assert_in_delta result, 100.0, 0.01
    end

    test "maps midpoint value to center of y range" do
      result = ChartUtils.normalize_y(500, 1000, {100, 0, 1000})
      assert_in_delta result, 50.0, 0.01
    end

    test "clamps value to cap before normalizing" do
      result_capped = ChartUtils.normalize_y(9999, 1000, {100, 0, 1000})
      result_at_max = ChartUtils.normalize_y(1000, 1000, {100, 0, 1000})
      assert_in_delta result_capped, result_at_max, 0.01
    end
  end
end
