defmodule Holter.Monitoring.Metrics do
  @moduledoc false

  import Ecto.Query
  alias Holter.Repo
  alias Holter.Monitoring.DailyMetric

  def list_daily_metrics(monitor_id) do
    DailyMetric
    |> where([m], m.monitor_id == ^monitor_id)
    |> order_by([m], desc: m.date)
    |> Repo.all()
  end

  def get_daily_metric(monitor_id, date) do
    Repo.get_by(DailyMetric, monitor_id: monitor_id, date: date)
  end

  def upsert_daily_metric(attrs) do
    %DailyMetric{}
    |> DailyMetric.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :monitor_id, :date, :inserted_at]},
      conflict_target: [:monitor_id, :date]
    )
  end
end
