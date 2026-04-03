defmodule Holter.Monitoring.Workers.MonitorDispatcher do
  @moduledoc """
  Worker for dispatching periodic monitor checks.
  """
  use Oban.Worker, queue: :dispatchers, max_attempts: 1

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.{HTTPCheck, SSLCheck}

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    monitors = Monitoring.list_monitors_for_dispatch()

    jobs =
      Enum.flat_map(monitors, fn monitor ->
        http_job = HTTPCheck.new(%{id: monitor.id})

        if String.starts_with?(monitor.url, "https") and !monitor.ssl_ignore do
          [http_job, SSLCheck.new(%{id: monitor.id})]
        else
          [http_job]
        end
      end)

    if Enum.any?(jobs) do
      Oban.insert_all(jobs)
    end

    :ok
  end
end
