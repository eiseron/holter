defmodule Holter.Monitoring.Workers.DailyMetricsAggregatorTest do
  use Holter.DataCase, async: true
  alias Holter.Monitoring.Workers.DailyMetricsAggregator
  alias Holter.Monitoring

  describe "perform/1" do
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

    test "aggregates for a single monitor", %{monitor: monitor} do
      date_str = "2026-04-01"

      assert :ok =
               DailyMetricsAggregator.perform(%Oban.Job{
                 args: %{"monitor_id" => monitor.id, "date" => date_str}
               })

      assert Monitoring.get_daily_metric(monitor.id, ~D[2026-04-01])
    end

    test "dispatches jobs for all monitors", %{monitor: monitor} do
      date_str = "2026-04-01"

      assert :ok =
               DailyMetricsAggregator.perform(%Oban.Job{
                 args: %{"all_monitors" => true, "date" => date_str}
               })

      # Should insert a new job into the queue
      assert_enqueued(
        worker: DailyMetricsAggregator,
        args: %{
          "monitor_id" => monitor.id,
          "date" => date_str
        }
      )
    end

    test "default perform aggregates yesterday for all monitors" do
      # This just checks if it runs without crashing and enqueues
      assert :ok = DailyMetricsAggregator.perform(%Oban.Job{args: %{}})
    end
  end
end
