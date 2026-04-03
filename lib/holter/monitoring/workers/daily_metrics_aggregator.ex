defmodule Holter.Monitoring.Workers.DailyMetricsAggregator do
  @moduledoc """
  Worker for aggregating daily monitor performance metrics.
  """
  use Oban.Worker, queue: :metrics, max_attempts: 3

  alias Holter.Monitoring
  alias Holter.Monitoring.Aggregator

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"monitor_id" => monitor_id, "date" => date_str}}) do
    date = Date.from_iso8601!(date_str)
    Aggregator.aggregate_monitor_date(monitor_id, date)
    :ok
  end

  def perform(%Oban.Job{args: %{"all_monitors" => true, "date" => date_str}}) do
    monitors = Monitoring.list_monitors()

    jobs =
      Enum.map(monitors, fn monitor ->
        new(%{monitor_id: monitor.id, date: date_str})
      end)

    if Enum.any?(jobs), do: Oban.insert_all(jobs)

    :ok
  end

  def perform(%Oban.Job{}) do
    yesterday = Date.utc_today() |> Date.add(-1)
    perform(%Oban.Job{args: %{"all_monitors" => true, "date" => Date.to_iso8601(yesterday)}})
  end
end
