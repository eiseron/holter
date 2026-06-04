defmodule HolterWeb.Api.IntegrationEventJSON do
  @moduledoc """
  JSON view for the integration_events resource (paginated audit log).
  """
  alias Holter.Integrations.Models.IntegrationEvent

  def index(%{
        events: %{
          events: events,
          page_number: page,
          page_size: page_size,
          total_pages: total_pages
        }
      }) do
    %{
      data: Enum.map(events, &data/1),
      meta: %{page: page, page_size: page_size, total_pages: total_pages}
    }
  end

  def show(%{event: event}) do
    %{data: data(event)}
  end

  defp data(%IntegrationEvent{} = event) do
    %{
      id: event.id,
      integration_id: event.integration_id,
      direction: event.direction,
      action: event.action,
      target: event.target,
      payload_redacted: event.payload_redacted,
      status: event.status,
      duration_ms: event.duration_ms,
      occurred_at: event.occurred_at,
      inserted_at: event.inserted_at
    }
  end
end
