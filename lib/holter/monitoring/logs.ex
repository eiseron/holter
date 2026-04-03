defmodule Holter.Monitoring.Logs do
  @moduledoc false

  import Ecto.Query
  alias Holter.Repo
  alias Holter.Monitoring.MonitorLog

  def list_monitor_logs(monitor_id) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> order_by([l], desc: l.checked_at)
    |> limit(100)
    |> Repo.all()
  end

  def get_monitor_log!(id), do: Repo.get!(MonitorLog, id)

  def create_monitor_log(attrs \\ %{}) do
    case %MonitorLog{}
         |> MonitorLog.changeset(attrs)
         |> Repo.insert() do
      {:ok, log} ->
        broadcast({:ok, log}, :log_created)
        {:ok, log}

      error ->
        error
    end
  end

  defp broadcast({:ok, log}, event) do
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitor:#{log.monitor_id}", {event, log})
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitors", {event, log})
    {:ok, log}
  end

  defp broadcast(error, _), do: error
end
