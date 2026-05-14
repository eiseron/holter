defmodule Holter.Integrations.IntegrationEventsContext do
  @moduledoc """
  Coordinator for the `integration_events` table.

  IntegrationEvent is append-only: insert via `log_event!/1`,
  query via `list_events/2`. No updates or deletes are exposed
  from this module — events are immutable audit records.
  """

  import Ecto.Query

  alias Holter.Integrations.Models.IntegrationEvent
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

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [e], e.status == ^status)

  defp filter_by_direction(query, nil), do: query
  defp filter_by_direction(query, dir), do: where(query, [e], e.direction == ^dir)
end
