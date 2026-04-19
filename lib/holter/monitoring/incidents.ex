defmodule Holter.Monitoring.Incidents do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.{Broadcaster, Incident}
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
        Broadcaster.broadcast({:ok, incident}, :incident_created, incident.monitor_id)
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
        Broadcaster.broadcast({:ok, updated}, :incident_updated, updated.monitor_id)
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
        Broadcaster.broadcast({:ok, updated}, :incident_resolved, updated.monitor_id)
        {:ok, updated}

      error ->
        error
    end
  end
end
