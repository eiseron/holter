defmodule HolterWeb.Api.MonitorJSON do
  @moduledoc """
  JSON view for rendering monitor data.
  """
  alias Holter.Monitoring.Monitor

  def index(%{monitors: %{data: monitors, meta: meta}}) do
    %{
      data: for(monitor <- monitors, do: data(monitor)),
      meta: meta
    }
  end

  def show(%{monitor: monitor}) do
    %{data: data(monitor)}
  end

  defp data(%Monitor{} = monitor) do
    %{
      id: monitor.id,
      url: monitor.url,
      method: monitor.method,
      interval_seconds: monitor.interval_seconds,
      timeout_seconds: monitor.timeout_seconds,
      health_status: monitor.health_status,
      logical_state: monitor.logical_state,
      last_checked_at: monitor.last_checked_at,
      inserted_at: monitor.inserted_at,
      updated_at: monitor.updated_at
    }
  end
end
