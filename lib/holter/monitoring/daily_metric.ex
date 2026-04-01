defmodule Holter.Monitoring.DailyMetric do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "daily_metrics" do
    field :date, :date
    field :uptime_percent, :decimal, default: 0.0
    field :avg_latency_ms, :integer, default: 0
    field :total_downtime_minutes, :integer, default: 0

    belongs_to :monitor, Holter.Monitoring.Monitor

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(daily_metric, attrs) do
    daily_metric
    |> cast(attrs, [:monitor_id, :date, :uptime_percent, :avg_latency_ms, :total_downtime_minutes])
    |> validate_required([
      :monitor_id,
      :date,
      :uptime_percent,
      :avg_latency_ms,
      :total_downtime_minutes
    ])
    |> unique_constraint([:monitor_id, :date])
  end
end
