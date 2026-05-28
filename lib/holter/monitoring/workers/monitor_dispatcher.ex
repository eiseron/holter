defmodule Holter.Monitoring.Workers.MonitorDispatcher do
  @moduledoc """
  Worker for dispatching periodic monitor checks.
  """
  use Oban.Worker, queue: :dispatchers, max_attempts: 1

  alias Eiseron.Network.Guard, as: NetworkGuard
  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.{DomainCheck, HTTPCheck, SSLCheck}
  alias Holter.Repo.Tenant

  @domain_check_interval_seconds 24 * 60 * 60

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    jobs =
      Monitoring.list_workspaces()
      |> Enum.flat_map(fn workspace ->
        Tenant.with_workspace!(workspace.id, fn ->
          workspace.id
          |> Monitoring.list_monitors_for_dispatch()
          |> Enum.flat_map(&jobs_for_monitor(&1, now))
        end)
      end)

    if Enum.any?(jobs) do
      Oban.insert_all(jobs)
    end

    :ok
  end

  defp jobs_for_monitor(monitor, now) do
    ctx = %{monitor: monitor, now: now}
    args = %{id: monitor.id, workspace_id: monitor.workspace_id}

    [HTTPCheck.new(args)]
    |> maybe_add_ssl_check(ctx, args)
    |> maybe_add_domain_check(ctx, args)
  end

  defp maybe_add_ssl_check(jobs, %{monitor: monitor}, args) do
    if String.starts_with?(monitor.url, "https") and !monitor.ssl_ignore do
      jobs ++ [SSLCheck.new(args)]
    else
      jobs
    end
  end

  defp maybe_add_domain_check(jobs, %{monitor: monitor, now: now}, args) do
    if should_run_domain_check?(monitor, now) do
      jobs ++ [DomainCheck.new(args)]
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
