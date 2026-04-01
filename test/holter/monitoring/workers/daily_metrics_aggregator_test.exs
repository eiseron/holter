defmodule Holter.Monitoring.Workers.DailyMetricsAggregatorTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo
  alias Holter.Monitoring.Workers.DailyMetricsAggregator
  alias Holter.Monitoring

  setup do
    {:ok, monitor} =
      Monitoring.create_monitor(%{
        url: "https://example.com",
        method: :GET,
        interval_seconds: 60,
        timeout_seconds: 30
      })

    %{monitor: monitor}
  end

  describe "when aggregating for a single monitor" do
    setup %{monitor: monitor} do
      date_str = "2026-04-01"
      :ok = perform_job(DailyMetricsAggregator, %{"monitor_id" => monitor.id, "date" => date_str})
      %{date: ~D[2026-04-01]}
    end

    test "creates a daily metric record", %{monitor: monitor, date: date} do
      assert Monitoring.get_daily_metric(monitor.id, date)
    end
  end

  describe "when dispatching jobs for all monitors" do
    setup %{monitor: monitor} do
      date_str = "2026-04-01"
      :ok = perform_job(DailyMetricsAggregator, %{"all_monitors" => true, "date" => date_str})
      %{date_str: date_str, monitor: monitor}
    end

    test "enqueues aggregation jobs for each monitor", %{monitor: monitor, date_str: date_str} do
      assert_enqueued(
        worker: DailyMetricsAggregator,
        args: %{
          "monitor_id" => monitor.id,
          "date" => date_str
        }
      )
    end
  end

  describe "when running default aggregation (no args)" do
    setup do
      :ok = perform_job(DailyMetricsAggregator, %{})
      :ok
    end

    test "enqueues aggregation jobs for each monitor for yesterday", %{monitor: monitor} do
      yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()

      assert_enqueued(
        worker: DailyMetricsAggregator,
        args: %{
          "monitor_id" => monitor.id,
          "date" => yesterday
        }
      )
    end
  end
end
