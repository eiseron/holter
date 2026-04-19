defmodule Holter.Monitoring.DateFilterTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.DateFilter

  describe "parse_to_datetime/3 with :start type" do
    test "returns a successful result for a valid date" do
      assert {:ok, _} = DateFilter.parse_to_datetime("2026-04-15", :start, "Etc/UTC")
    end

    test "returns UTC midnight for the given date — year" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "Etc/UTC")
      assert dt.year == 2026
    end

    test "returns UTC midnight for the given date — month" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "Etc/UTC")
      assert dt.month == 4
    end

    test "returns UTC midnight for the given date — day" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "Etc/UTC")
      assert dt.day == 15
    end

    test "returns UTC midnight for the given date — hour is 0" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "Etc/UTC")
      assert dt.hour == 0
    end

    test "returns UTC midnight for the given date — minute is 0" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "Etc/UTC")
      assert dt.minute == 0
    end

    test "returns UTC midnight for the given date — second is 0" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "Etc/UTC")
      assert dt.second == 0
    end

    test "shifts timezone offset to UTC" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "America/New_York")
      assert dt.time_zone == "Etc/UTC"
    end

    test "converts timezone offset to correct UTC hour" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :start, "America/New_York")
      assert dt.hour == 4
    end
  end

  describe "parse_to_datetime/3 with :end type" do
    test "returns UTC end of day — hour is 23" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :end, "Etc/UTC")
      assert dt.hour == 23
    end

    test "returns UTC end of day — minute is 59" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :end, "Etc/UTC")
      assert dt.minute == 59
    end

    test "returns UTC end of day — second is 59" do
      {:ok, dt} = DateFilter.parse_to_datetime("2026-04-15", :end, "Etc/UTC")
      assert dt.second == 59
    end
  end

  describe "parse_to_datetime/3 error cases" do
    test "returns :error for invalid date string" do
      assert DateFilter.parse_to_datetime("not-a-date", :start, "Etc/UTC") == :error
    end

    test "returns :error for invalid timezone" do
      assert DateFilter.parse_to_datetime("2026-04-15", :start, "Not/ATimezone") == :error
    end

    test "returns :error for empty string" do
      assert DateFilter.parse_to_datetime("", :start, "Etc/UTC") == :error
    end
  end
end
