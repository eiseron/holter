defmodule HolterWeb.Api.MonitorLogJSON do
  @moduledoc """
  JSON view for rendering monitor log data.
  """
  alias Holter.Monitoring.MonitorLog

  def index(%{
        logs: %{logs: logs, page_number: page, total_pages: total_pages, page_size: page_size}
      }) do
    %{
      data: for(log <- logs, do: summary(log)),
      meta: %{page: page, page_size: page_size, total_pages: total_pages}
    }
  end

  def show(%{log: log}) do
    %{data: detail(log)}
  end

  defp summary(%MonitorLog{} = log) do
    %{
      id: log.id,
      status: log.status,
      status_code: log.status_code,
      latency_ms: log.latency_ms,
      region: log.region,
      error_message: log.error_message,
      redirect_count: log.redirect_count,
      checked_at: log.checked_at,
      inserted_at: log.inserted_at
    }
  end

  defp detail(%MonitorLog{} = log) do
    %{
      id: log.id,
      status: log.status,
      status_code: log.status_code,
      latency_ms: log.latency_ms,
      region: log.region,
      response_snippet: log.response_snippet,
      response_headers: log.response_headers,
      response_ip: log.response_ip,
      error_message: log.error_message,
      redirect_count: log.redirect_count,
      last_redirect_url: log.last_redirect_url,
      redirect_list: log.redirect_list,
      monitor_snapshot: log.monitor_snapshot,
      checked_at: log.checked_at,
      inserted_at: log.inserted_at,
      updated_at: log.updated_at
    }
  end
end
