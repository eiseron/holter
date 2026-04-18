defmodule HolterWeb.TimezoneTest do
  use ExUnit.Case, async: true

  alias HolterWeb.Timezone

  describe "format_datetime/2" do
    test "formats UTC datetime in user timezone" do
      utc = ~U[2026-04-18 15:00:00Z]
      assert Timezone.format_datetime(utc, "America/Sao_Paulo") == "2026-04-18 12:00:00"
    end

    test "falls back to UTC when timezone is invalid" do
      utc = ~U[2026-04-18 15:00:00Z]
      assert Timezone.format_datetime(utc, "Invalid/Zone") == "2026-04-18 15:00:00"
    end

    test "returns empty string for nil" do
      assert Timezone.format_datetime(nil, "America/Sao_Paulo") == ""
    end

    test "handles UTC timezone explicitly" do
      utc = ~U[2026-04-18 15:00:00Z]
      assert Timezone.format_datetime(utc, "Etc/UTC") == "2026-04-18 15:00:00"
    end
  end

  describe "local_day_boundaries/2" do
    test "returns start boundary in UTC for local timezone" do
      {:ok, start_utc, _end_utc} =
        Timezone.local_day_boundaries("2026-04-18", "America/Sao_Paulo")

      assert start_utc == ~U[2026-04-18 03:00:00Z]
    end

    test "returns end boundary in UTC for local timezone" do
      {:ok, _start_utc, end_utc} =
        Timezone.local_day_boundaries("2026-04-18", "America/Sao_Paulo")

      assert end_utc == ~U[2026-04-19 02:59:59Z]
    end

    test "start boundary equals midnight UTC for UTC timezone" do
      {:ok, start_utc, _end_utc} = Timezone.local_day_boundaries("2026-04-18", "Etc/UTC")
      assert start_utc == ~U[2026-04-18 00:00:00Z]
    end

    test "end boundary equals end of day UTC for UTC timezone" do
      {:ok, _start_utc, end_utc} = Timezone.local_day_boundaries("2026-04-18", "Etc/UTC")
      assert end_utc == ~U[2026-04-18 23:59:59Z]
    end

    test "returns error for invalid date string" do
      assert Timezone.local_day_boundaries("not-a-date", "Etc/UTC") == :error
    end

    test "returns error for invalid timezone" do
      assert Timezone.local_day_boundaries("2026-04-18", "Invalid/Zone") == :error
    end
  end

  describe "valid_timezone?/1" do
    test "returns true for America/Sao_Paulo" do
      assert Timezone.valid_timezone?("America/Sao_Paulo")
    end

    test "returns true for Etc/UTC" do
      assert Timezone.valid_timezone?("Etc/UTC")
    end

    test "returns false for invalid timezone string" do
      refute Timezone.valid_timezone?("Invalid/Zone")
    end
  end
end
