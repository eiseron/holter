defmodule Holter.Observability.ObanHandler do
  @moduledoc """
  Telemetry handler to enrich Logger metadata with Oban job context.
  """
  require Logger

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
    metadata = %{
      job_id: job.id,
      job_worker: inspect(job.worker),
      job_queue: job.queue,
      context: :oban_job
    }

    Logger.metadata(Map.to_list(metadata))

    if Code.ensure_loaded?(Sentry.Context) do
      Sentry.Context.set_tags_context(metadata)
    end
  end

  def handle_event(_event, _measurements, _metadata, _config) do
    :ok
  end
end
