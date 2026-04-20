defmodule Holter.Monitoring.Workers.DailyMetricsAggregator do
  @moduledoc """
  Worker for aggregating daily monitor performance metrics and orchestrating Backfill logic.
  """
  use Oban.Worker, queue: :metrics, max_attempts: 3

  import Ecto.Query

  alias Holter.Monitoring
  alias Holter.Monitoring.Aggregator
  alias Holter.Monitoring.DailyMetric
  alias Holter.Monitoring.Workers.LogsPruner
  alias Holter.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"monitor_id" => monitor_id, "date" => date_str}}) do
    date = Date.from_iso8601!(date_str)

    Aggregator.aggregate_monitor_date(monitor_id, date)

    %{monitor_id: monitor_id}
    |> LogsPruner.new()
    |> Oban.insert!()

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
    last_date = get_last_aggregated_date() || Date.add(yesterday, -7)

    generate_staggered_jobs(last_date, yesterday)

    :ok
  end

  defp get_last_aggregated_date do
    DailyMetric
    |> select([m], max(m.date))
    |> Repo.one()
  end

  defp generate_staggered_jobs(last_date, yesterday) do
    start_date =
      if Date.compare(last_date, yesterday) in [:gt, :eq] do
        yesterday
      else
        Date.add(last_date, 1)
      end

    Date.range(start_date, yesterday)
    |> Enum.with_index()
    |> Enum.each(fn {date, index} ->
      delay_seconds = index * 15 * 60

      %{all_monitors: true, date: Date.to_iso8601(date)}
      |> new(schedule_in: delay_seconds)
      |> Oban.insert!()
    end)
  end
end
