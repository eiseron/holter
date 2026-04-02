defmodule Holter.Monitoring.Logs do
  @moduledoc false

  import Ecto.Query
  alias Holter.Repo
  alias Holter.Monitoring.MonitorLog

  def list_monitor_logs(monitor_id) do
    MonitorLog
    |> where([l], l.monitor_id == ^monitor_id)
    |> order_by([l], desc: l.checked_at)
    |> Repo.all()
  end

  def create_monitor_log(attrs \\ %{}) do
    %MonitorLog{}
    |> MonitorLog.changeset(attrs)
    |> Repo.insert()
  end
end
