defmodule Holter.Monitoring.Workers.MonitorDispatcher do
  @moduledoc """
  Worker for dispatching periodic monitor checks.
  """
  use Oban.Worker, queue: :dispatchers, max_attempts: 1

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.{DomainCheck, HTTPCheck, SSLCheck}
  alias Holter.Network.Guard, as: NetworkGuard

  @domain_check_interval_seconds 24 * 60 * 60

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    monitors = Monitoring.list_monitors_for_dispatch()

    jobs = Enum.flat_map(monitors, &jobs_for_monitor(&1, now))

    if Enum.any?(jobs) do
      Oban.insert_all(jobs)
    end

    :ok
  end

  defp jobs_for_monitor(monitor, now) do
    [HTTPCheck.new(%{id: monitor.id})]
    |> maybe_add_ssl_check(monitor)
    |> maybe_add_domain_check(monitor, now)
  end

  defp maybe_add_ssl_check(jobs, monitor) do
    if String.starts_with?(monitor.url, "https") and !monitor.ssl_ignore do
      jobs ++ [SSLCheck.new(%{id: monitor.id})]
    else
      jobs
    end
  end

  defp maybe_add_domain_check(jobs, monitor, now) do
    if should_run_domain_check?(monitor, now) do
      jobs ++ [DomainCheck.new(%{id: monitor.id})]
    else
      jobs
    end
  end

  defp should_run_domain_check?(%{domain_check_ignore: true}, _now), do: false

  defp should_run_domain_check?(monitor, now) do
    host = URI.parse(monitor.url).host

    cond do
      is_nil(host) -> false
      ip_literal?(host) -> false
      NetworkGuard.restricted_host?(host) -> false
      due_for_domain_check?(monitor.last_domain_check_at, now) -> true
      true -> false
    end
  end

  defp ip_literal?(host) do
    case :inet.parse_address(to_charlist(host)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp due_for_domain_check?(nil, _now), do: true

  defp due_for_domain_check?(last_at, now),
    do: DateTime.diff(now, last_at, :second) >= @domain_check_interval_seconds
end
