defmodule HolterWeb.Components.Monitoring.IntervalFormatTest do
  use ExUnit.Case, async: true

  alias HolterWeb.Components.Monitoring.IntervalFormat

  describe "format_label/1" do
    test "renders one minute" do
      assert IntervalFormat.format_label(60) == "1 min"
    end

    test "renders thirty minutes" do
      assert IntervalFormat.format_label(1800) == "30 min"
    end

    test "renders an exact hour" do
      assert IntervalFormat.format_label(3600) == "1 h"
    end

    test "renders two hours" do
      assert IntervalFormat.format_label(7200) == "2 h"
    end

    test "renders twenty-four hours" do
      assert IntervalFormat.format_label(86_400) == "24 h"
    end

    test "renders mixed hours and minutes" do
      assert IntervalFormat.format_label(5400) == "1 h 30 min"
    end

    test "renders a single trailing minute" do
      assert IntervalFormat.format_label(3660) == "1 h 1 min"
    end

    test "renders zero as 0 min" do
      assert IntervalFormat.format_label(0) == "0 min"
    end
  end
end
