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
end
