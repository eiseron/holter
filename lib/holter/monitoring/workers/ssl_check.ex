defmodule Holter.Monitoring.Workers.SSLCheck do
  use Oban.Worker, queue: :checks, max_attempts: 2

  alias Holter.Monitoring
  alias Holter.Monitoring.SecurityScanner

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)
    client = get_client()

    if String.starts_with?(monitor.url, "https") do
      case client.get_ssl_expiration(monitor.url) do
        {:ok, expiration_date} ->
          SecurityScanner.process_ssl(monitor, expiration_date)

        {:error, reason} ->
          require Logger
          Logger.error("Failed to check SSL for monitor #{monitor.id}: #{inspect(reason)}")
      end
    end

    :ok
  end

  defp get_client do
    Application.get_env(:holter, :monitor_client, Holter.Monitoring.MonitorClient.HTTP)
  end
end
