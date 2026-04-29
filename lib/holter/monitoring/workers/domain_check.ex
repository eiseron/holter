defmodule Holter.Monitoring.Workers.DomainCheck do
  @moduledoc """
  Oban worker that performs a per-monitor RDAP lookup and feeds the result
  into `DomainScanner.process_domain/2`.

  Lookup failures are logged but do **not** open `:domain_expiry` incidents.
  RDAP errors are usually transient (registrar-side rate limits or downtime),
  not signals that the user's domain is at risk; conflating them would create
  noisy alerts. `last_domain_check_at` is bumped on both success and failure
  to keep the dispatcher's 24h cadence honest.
  """
  use Oban.Worker,
    queue: :checks,
    max_attempts: 2,
    unique: [period: 60, states: [:available, :scheduled, :executing]]

  alias Holter.Monitoring
  alias Holter.Monitoring.DomainScanner

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    process_check(monitor, now)
    :ok
  end

  defp process_check(%{domain_check_ignore: true} = monitor, now) do
    DomainScanner.resolve_domain_incident(monitor, now)
  end

  defp process_check(monitor, _now) do
    monitor.url
    |> URI.parse()
    |> Map.get(:host)
    |> fetch_expiration()
    |> handle_expiration_result(monitor)
  end

  defp fetch_expiration(nil), do: {:error, :no_host}

  defp fetch_expiration(host) do
    client = Application.get_env(:holter, :monitor_client, Holter.Monitoring.MonitorClient.HTTP)
    client.get_domain_expiration(host)
  end

  defp handle_expiration_result({:ok, expiration_date}, monitor) do
    DomainScanner.process_domain(monitor, expiration_date)
  end

  defp handle_expiration_result({:error, reason}, monitor) do
    Logger.error("Failed to check domain for monitor #{monitor.id}: #{inspect(reason)}")
    DomainScanner.handle_domain_error(monitor, reason)
    :ok
  end
end
