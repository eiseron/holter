defmodule Holter.Monitoring.Metrics do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.DailyMetric
  alias Holter.Repo

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
    case %DailyMetric{}
         |> DailyMetric.changeset(attrs)
         |> Repo.insert(
           on_conflict: {:replace_all_except, [:id, :monitor_id, :date, :inserted_at]},
           conflict_target: [:monitor_id, :date]
         ) do
      {:ok, metric} ->
        broadcast({:ok, metric}, :metric_updated)
        {:ok, metric}

      error ->
        error
    end
  end

  defp broadcast({:ok, metric}, event) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "monitoring:monitor:#{metric.monitor_id}",
      {event, metric}
    )

    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitors", {event, metric})
    {:ok, metric}
  end

  defp broadcast(error, _), do: error
end
