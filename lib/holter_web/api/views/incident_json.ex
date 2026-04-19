defmodule HolterWeb.Api.IncidentJSON do
  @moduledoc """
  JSON view for rendering incident data.
  """
  alias Holter.Monitoring.Incident

  def index(%{incidents: incidents}) do
    %{data: for(incident <- incidents, do: data(incident))}
  end

  def show(%{incident: incident}) do
    %{data: data(incident)}
  end

  defp data(%Incident{} = incident) do
    %{
      id: incident.id,
      type: incident.type,
      started_at: incident.started_at,
      resolved_at: incident.resolved_at,
      duration_seconds: incident.duration_seconds,
      root_cause: incident.root_cause,
      monitor_snapshot: incident.monitor_snapshot,
      inserted_at: incident.inserted_at,
      updated_at: incident.updated_at
    }
  end
end
