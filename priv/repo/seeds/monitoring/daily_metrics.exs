defmodule Holter.Seeds.Monitoring.DailyMetrics do
  @moduledoc false

  alias Holter.Monitoring.DailyMetric
  alias Holter.Repo

  def create_for(monitors) do
    today = Date.utc_today()

    rows = [
      {monitors.healthy_example, [0, 1, 2, 3, 4, 5, 6]},
      {monitors.healthy_github, [0, 1, 2, 3, 4, 5, 6]},
      {monitors.ssl_expiring, [0, 1, 2]}
    ]

    for {monitor, offsets} <- rows, offset <- offsets do
      %DailyMetric{}
      |> DailyMetric.changeset(%{
        monitor_id: monitor.id,
        date: Date.add(today, -offset),
        uptime_percent: Decimal.new("99.95"),
        avg_latency_ms: 180 + offset * 5,
        total_downtime_minutes: 0
      })
      |> Repo.insert!()
    end

    IO.puts("[seeds] Created daily metrics for healthy monitors")
    :ok
  end
end
