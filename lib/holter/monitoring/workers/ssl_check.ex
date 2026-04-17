defmodule Holter.Monitoring.Workers.SSLCheck do
  @moduledoc """
  Oban worker responsible for performing SSL expiration and handshake checks.
  """
  use Oban.Worker,
    queue: :checks,
    max_attempts: 2,
    unique: [period: 60, states: [:available, :scheduled, :executing]]

  alias Holter.Monitoring
  alias Holter.Monitoring.SecurityScanner

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    process_check(monitor, now)
    :ok
  end

  defp process_check(%{ssl_ignore: true} = monitor, now) do
    SecurityScanner.resolve_ssl_incident(monitor, now)
  end

  defp process_check(%{url: "https" <> _} = monitor, _now) do
    monitor.url
    |> fetch_expiration()
    |> handle_expiration_result(monitor)
  end

  defp process_check(_monitor, _now), do: :ok

  defp fetch_expiration(url) do
    client = Application.get_env(:holter, :monitor_client, Holter.Monitoring.MonitorClient.HTTP)
    client.get_ssl_expiration(url)
  end

  defp handle_expiration_result({:ok, expiration_date}, monitor) do
    SecurityScanner.process_ssl(monitor, expiration_date)
  end

  defp handle_expiration_result({:error, reason}, monitor) do
    require Logger
    Logger.error("Failed to check SSL for monitor #{monitor.id}: #{inspect(reason)}")
    SecurityScanner.handle_ssl_error(monitor, reason)
    :ok
  end
end
