defmodule HolterWeb.Api.DeliveryLogJSON do
  alias Holter.Delivery.ChannelLogs

  def index(%{
        logs: %{logs: logs, page_number: page, total_pages: total_pages, page_size: page_size}
      }) do
    %{
      data: for(job <- logs, do: data(job)),
      meta: %{page: page, page_size: page_size, total_pages: total_pages}
    }
  end

  defp data(%Oban.Job{} = job) do
    %{
      id: job.id,
      status: ChannelLogs.classify_delivery_status(job),
      event: ChannelLogs.format_event_type(job),
      worker: job.worker,
      errors: Enum.map(job.errors, & &1["error"]),
      attempted_at: job.attempted_at,
      inserted_at: job.inserted_at
    }
  end
end
