defmodule Holter.Integrations.IntegrationEventsContext do
  @moduledoc """
  Coordinator for the `integration_events` table.

  IntegrationEvent is append-only: insert via `log_event!/1`,
  query via `list_events/2`. No updates or deletes are exposed
  from this module — events are immutable audit records.
  """

  import Ecto.Query

  alias Holter.Integrations.Models.IntegrationEvent
  alias Holter.Pagination
  alias Holter.Repo

  def log_event!(attrs) do
    %IntegrationEvent{}
    |> IntegrationEvent.insert_changeset(attrs)
    |> Repo.insert!()
  end

  def list_events(integration_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status_filter = Keyword.get(opts, :status)
    direction_filter = Keyword.get(opts, :direction)

    IntegrationEvent
    |> where([e], e.integration_id == ^integration_id)
    |> filter_by_status(status_filter)
    |> filter_by_direction(direction_filter)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_events_paginated(integration_id, page, page_size) do
    IntegrationEvent
    |> where([e], e.integration_id == ^integration_id)
    |> order_by([e], desc: e.occurred_at)
    |> Pagination.paginate_query(page, page_size)
    |> Repo.all()
  end

  def events_page_info(integration_id, page_size, requested_page) do
    base_query = where(IntegrationEvent, [e], e.integration_id == ^integration_id)

    {_total_count, total_pages, current_page} =
      Pagination.calculate(base_query, page_size, requested_page)

    {total_pages, current_page}
  end

  def list_events_page(integration_id, filters \\ %{}) do
    page_size = Pagination.resolve_page_size(filters[:page_size], default: 25)
    requested_page = filters[:page]

    {total_pages, current_page} =
      events_page_info(integration_id, page_size, requested_page)

    events = list_events_paginated(integration_id, current_page, page_size)

    %{
      events: events,
      page_number: current_page,
      total_pages: total_pages,
      page_size: page_size
    }
  end

  def get_event(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %IntegrationEvent{} = event <- Repo.get(IntegrationEvent, id) do
      {:ok, event}
    else
      _ -> {:error, :not_found}
    end
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [e], e.status == ^status)

  defp filter_by_direction(query, nil), do: query
  defp filter_by_direction(query, dir), do: where(query, [e], e.direction == ^dir)
end
