defmodule Holter.Observability.ObanHandler do
  @moduledoc """
  Telemetry handler to enrich Logger metadata with Oban job context.
  """
  require Logger

  @doc """
  Attaches the handler to Oban job events.
  """
  def attach do
    :telemetry.attach_many(
      "holter-oban-logger",
      [
        [:oban, :job, :start],
        [:oban, :job, :stop],
        [:oban, :job, :exception]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:oban, :job, :start], _measurements, %{job: job}, _config) do
    Logger.metadata(
      job_id: job.id,
      job_worker: job.worker,
      job_queue: job.queue,
      context: :oban_job
    )
  end

  def handle_event(_event, _measurements, _metadata, _config) do
    :ok
  end
end
