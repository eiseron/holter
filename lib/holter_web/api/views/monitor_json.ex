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
      ssl_ignore: monitor.ssl_ignore,
      follow_redirects: monitor.follow_redirects,
      max_redirects: monitor.max_redirects,
      headers: monitor.headers,
      body: monitor.body,
      keyword_positive: monitor.keyword_positive,
      keyword_negative: monitor.keyword_negative,
      last_checked_at: monitor.last_checked_at,
      last_success_at: monitor.last_success_at,
      ssl_expires_at: monitor.ssl_expires_at,
      inserted_at: monitor.inserted_at,
      updated_at: monitor.updated_at
    }
  end
end
