defmodule Holter.Monitoring.Workers.SSLCheck do
  use Oban.Worker, queue: :checks, max_attempts: 2

  alias Holter.Monitoring
  alias Holter.Monitoring.SecurityScanner

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    monitor = Monitoring.get_monitor!(id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    cond do
      monitor.ssl_ignore ->
        SecurityScanner.resolve_ssl_incident(monitor, now)
        :ok

      String.starts_with?(monitor.url, "https") ->
        client = get_client()

        case client.get_ssl_expiration(monitor.url) do
          {:ok, expiration_date} ->
            SecurityScanner.process_ssl(monitor, expiration_date)

          {:error, reason} ->
            require Logger
            Logger.error("Failed to check SSL for monitor #{monitor.id}: #{inspect(reason)}")
        end

        :ok

      true ->
        :ok
    end
  end

  defp get_client do
    Application.get_env(:holter, :monitor_client, Holter.Monitoring.MonitorClient.HTTP)
  end
end
