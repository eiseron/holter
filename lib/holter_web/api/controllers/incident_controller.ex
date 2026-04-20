defmodule HolterWeb.Api.IncidentController do
  @moduledoc """
  REST API Controller for Incidents.
  Includes OpenAPI 3.0 operation definitions.
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import HolterWeb.Api.ParamHelpers

  alias Holter.Monitoring
  alias HolterWeb.Api.IncidentSchemas

  action_fallback HolterWeb.Api.FallbackController

  tags(["Incidents"])

  operation(:index,
    summary: "List incidents",
    description:
      "List the history of downtime and alerts for a monitor with filtering and pagination.",
    parameters: [
      monitor_id: [
        in: :path,
        description: "Monitor UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ],
      page: [
        in: :query,
        description: "Page number",
        schema: %OpenApiSpex.Schema{type: :integer, default: 1}
      ],
      page_size: [
        in: :query,
        description: "Items per page (max 100)",
        schema: %OpenApiSpex.Schema{type: :integer, default: 25}
      ],
      type: [
        in: :query,
        description: "Filter by incident type (downtime, defacement, ssl_expiry)",
        schema: %OpenApiSpex.Schema{type: :string}
      ],
      state: [
        in: :query,
        description: "Filter by state (open, resolved)",
        schema: %OpenApiSpex.Schema{type: :string}
      ]
    ],
    responses: [
      ok: {"Incident list", "application/json", IncidentSchemas.incident_list()},
      not_found: {"Monitor not found", "application/json", IncidentSchemas.error()}
    ]
  )

  def index(conn, %{"monitor_id" => monitor_id} = params) do
    with {:ok, monitor} <- Monitoring.get_monitor(monitor_id) do
      filters = sanitize_filters(params)

      result =
        Monitoring.list_incidents_filtered(%{
          monitor_id: monitor.id,
          page: filters[:page] || 1,
          page_size: filters[:page_size] || 25,
          type: filters[:type],
          state: filters[:state]
        })

      render(conn, :index, result: result)
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

  @valid_types ~w(downtime defacement ssl_expiry)
  @valid_states ~w(open resolved)

  defp sanitize_filters(params) do
    %{}
    |> maybe_put_integer(params, {"page", :page})
    |> maybe_put_integer(params, {"page_size", :page_size})
    |> maybe_put_atom(params, {"type", :type, @valid_types})
    |> maybe_put_atom(params, {"state", :state, @valid_states})
  end
end
