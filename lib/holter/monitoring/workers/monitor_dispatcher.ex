defmodule Holter.Monitoring.Workers.MonitorDispatcher do
  use Oban.Worker, queue: :dispatchers, max_attempts: 1

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.HTTPCheck

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    monitors = Monitoring.list_monitors_for_dispatch()

    jobs =
      Enum.map(monitors, fn monitor ->
        HTTPCheck.new(%{id: monitor.id})
      end)

    if Enum.any?(jobs) do
      Oban.insert_all(jobs)
    end

    :ok
  end
end
