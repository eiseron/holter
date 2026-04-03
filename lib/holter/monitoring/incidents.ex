defmodule Holter.Monitoring.Incidents do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.Incident
  alias Holter.Repo

  def list_incidents(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> order_by([i], desc: i.started_at)
    |> Repo.all()
  end

  def get_open_incident(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id and is_nil(i.resolved_at))
    |> Repo.one()
  end

  def get_open_incident(monitor_id, type) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id and i.type == ^type and is_nil(i.resolved_at))
    |> Repo.one()
  end

  def list_open_incidents(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id and is_nil(i.resolved_at))
    |> Repo.all()
  end

  def create_incident(attrs \\ %{}) do
    case %Incident{}
         |> Incident.changeset(attrs)
         |> Repo.insert() do
      {:ok, incident} ->
        broadcast({:ok, incident}, :incident_created)
        {:ok, incident}

      error ->
        error
    end
  end

  def update_incident(%Incident{} = incident, attrs) do
    case incident
         |> Incident.changeset(attrs)
         |> Repo.update() do
      {:ok, updated} ->
        broadcast({:ok, updated}, :incident_updated)
        {:ok, updated}

      error ->
        error
    end
  end

  def resolve_incident(%Incident{} = incident, resolved_at) do
    duration = DateTime.diff(resolved_at, incident.started_at)

    case incident
         |> Incident.changeset(%{resolved_at: resolved_at, duration_seconds: duration})
         |> Repo.update() do
      {:ok, updated} ->
        broadcast({:ok, updated}, :incident_resolved)
        {:ok, updated}

      error ->
        error
    end
  end

  defp broadcast({:ok, incident}, event) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "monitoring:monitor:#{incident.monitor_id}",
      {event, incident}
    )

    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitors", {event, incident})
    {:ok, incident}
  end

  defp broadcast(error, _), do: error
end
