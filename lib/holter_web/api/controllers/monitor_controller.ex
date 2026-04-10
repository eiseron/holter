defmodule HolterWeb.Api.MonitorController do
  @moduledoc """
  REST API Controller for managing Monitors.
  Includes OpenAPI 3.0 operation definitions.
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor
  alias HolterWeb.Api.MonitorSchemas

  action_fallback HolterWeb.Api.FallbackController

  tags(["Monitors"])

  operation(:index,
    summary: "List monitors",
    description: "List all monitors for a workspace with pagination and filtering.",
    parameters: [
      workspace_slug: [
        in: :path,
        description: "Workspace slug",
        type: :string,
        example: "eiseron"
      ],
      page: [
        in: :query,
        description: "Page number",
        schema: %OpenApiSpex.Schema{type: :integer, default: 1}
      ],
      page_size: [
        in: :query,
        description: "Items per page",
        schema: %OpenApiSpex.Schema{type: :integer, default: 25}
      ],
      health_status: [in: :query, description: "Filter by health status", type: :string],
      logical_state: [in: :query, description: "Filter by logical state", type: :string]
    ],
    responses: [
      ok: {"Monitor list", "application/json", MonitorSchemas.monitor_list()},
      not_found: {"Workspace not found", "application/json", MonitorSchemas.error()}
    ]
  )

  def index(conn, %{"workspace_slug" => workspace_slug} = params) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      params =
        params
        |> Map.put(:workspace_id, workspace.id)
        |> sanitize_params()

      monitors = Monitoring.list_monitors_filtered(params)
      render(conn, :index, monitors: monitors)
    end
  end

  operation(:show,
    summary: "Get monitor",
    description: "Fetch a single monitor by its UUID.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string],
      id: [
        in: :path,
        description: "Monitor UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Monitor details", "application/json", MonitorSchemas.monitor_response()},
      not_found: {"Monitor not found", "application/json", MonitorSchemas.error()}
    ]
  )

  def show(conn, %{"workspace_slug" => workspace_slug, "id" => id}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         {:ok, monitor} <- Monitoring.get_monitor(id),
         true <- monitor.workspace_id == workspace.id || {:error, :not_found} do
      render(conn, :show, monitor: monitor)
    end
  end

  operation(:create,
    summary: "Create monitor",
    description: "Create a new monitor for the specified workspace.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    request_body: {"Monitor parameters", "application/json", MonitorSchemas.monitor_request()},
    responses: [
      created: {"Created monitor", "application/json", MonitorSchemas.monitor_response()},
      unprocessable_entity: {"Validation error", "application/json", MonitorSchemas.error()}
    ]
  )

  def create(conn, %{"workspace_slug" => workspace_slug} = params) do
    monitor_params = Map.drop(params, ["workspace_slug"])

    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         monitor_params = Map.put(monitor_params, "workspace_id", workspace.id),
         {:ok, %Monitor{} = monitor} <- Monitoring.create_monitor(monitor_params) do
      conn
      |> put_status(:created)
      |> render(:show, monitor: monitor)
    end
  end

  operation(:update,
    summary: "Update monitor",
    description: "Update an existing monitor's configuration.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string],
      id: [
        in: :path,
        description: "Monitor UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    request_body: {"Update parameters", "application/json", MonitorSchemas.monitor_request()},
    responses: [
      ok: {"Updated monitor", "application/json", MonitorSchemas.monitor_response()},
      not_found: {"Monitor not found", "application/json", MonitorSchemas.error()},
      unprocessable_entity: {"Validation error", "application/json", MonitorSchemas.error()}
    ]
  )

  def update(conn, %{"workspace_slug" => workspace_slug, "id" => id} = params) do
    monitor_params = Map.drop(params, ["workspace_slug", "id"])

    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         {:ok, monitor} <- Monitoring.get_monitor(id),
         true <- monitor.workspace_id == workspace.id || {:error, :not_found},
         {:ok, %Monitor{} = monitor} <- Monitoring.update_monitor(monitor, monitor_params) do
      render(conn, :show, monitor: monitor)
    end
  end

  operation(:delete,
    summary: "Delete monitor",
    description: "Permanently delete a monitor and all its associated data.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string],
      id: [
        in: :path,
        description: "Monitor UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      no_content: {"Deleted successfully", "application/json", nil},
      not_found: {"Monitor not found", "application/json", MonitorSchemas.error()}
    ]
  )

  def delete(conn, %{"workspace_slug" => workspace_slug, "id" => id}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         {:ok, monitor} <- Monitoring.get_monitor(id),
         true <- monitor.workspace_id == workspace.id || {:error, :not_found},
         {:ok, %Monitor{}} <- Monitoring.delete_monitor(monitor) do
      send_resp(conn, :no_content, "")
    end
  end

  defp sanitize_params(params) do
    params
    |> maybe_convert_param("page", :integer)
    |> maybe_convert_param("page_size", :integer)
    |> maybe_convert_param("health_status", :atom)
    |> maybe_convert_param("logical_state", :atom)
  end

  defp maybe_convert_param(params, key, :integer) do
    case Map.get(params, key) do
      val when is_binary(val) -> Map.put(params, String.to_atom(key), String.to_integer(val))
      val when is_integer(val) -> Map.put(params, String.to_atom(key), val)
      _ -> params
    end
  end

  defp maybe_convert_param(params, key, :atom) do
    case Map.get(params, key) do
      val when is_binary(val) ->
        Map.put(params, String.to_atom(key), String.to_existing_atom(val))

      _ ->
        params
    end
  rescue
    ArgumentError -> params
  end
end
