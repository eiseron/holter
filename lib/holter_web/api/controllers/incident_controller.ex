defmodule HolterWeb.Api.IncidentController do
  @moduledoc """
  REST API Controller for Incidents.
  Includes OpenAPI 3.0 operation definitions.
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Holter.Monitoring
  alias HolterWeb.Api.IncidentSchemas

  action_fallback HolterWeb.Api.FallbackController

  tags(["Incidents"])

  operation(:index,
    summary: "List incidents",
    description: "List the history of downtime and alerts for a monitor.",
    parameters: [
      monitor_id: [
        in: :path,
        description: "Monitor UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Incident list", "application/json", IncidentSchemas.incident_list()},
      not_found: {"Monitor not found", "application/json", IncidentSchemas.error()}
    ]
  )

  def index(conn, %{"monitor_id" => monitor_id}) do
    with {:ok, monitor} <- Monitoring.get_monitor(monitor_id) do
      incidents = Monitoring.list_incidents(monitor.id)
      render(conn, :index, incidents: incidents)
    end
  end

  operation(:show,
    summary: "Get incident details",
    description:
      "Retrieve a single incident by its UUID, including root cause and monitor snapshot.",
    parameters: [
      id: [
        in: :path,
        description: "Incident UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Incident details", "application/json", IncidentSchemas.incident()},
      not_found: {"Incident not found", "application/json", IncidentSchemas.error()}
    ]
  )

  def show(conn, %{"id" => id}) do
    with {:ok, incident} <- Monitoring.get_incident(id) do
      render(conn, :show, incident: incident)
    end
  end
end
