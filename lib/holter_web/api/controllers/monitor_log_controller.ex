defmodule HolterWeb.Api.MonitorLogController do
  @moduledoc """
  REST API Controller for Monitor Logs.
  Includes OpenAPI 3.0 operation definitions.
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import HolterWeb.Api.ParamHelpers

  alias Holter.Monitoring
  alias HolterWeb.Api.MonitorLogSchemas

  action_fallback HolterWeb.Api.FallbackController

  tags(["Logs"])

  operation(:index,
    summary: "List monitor logs",
    description: "List check logs for a monitor with pagination, status filter, and sorting.",
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
        description: "Items per page",
        schema: %OpenApiSpex.Schema{type: :integer, default: 50}
      ],
      status: [
        in: :query,
        description: "Filter by status (up, down, degraded, compromised, unknown)",
        type: :string
      ],
      sort_by: [
        in: :query,
        description: "Sort column (checked_at, status, latency_ms)",
        type: :string
      ],
      sort_dir: [in: :query, description: "Sort direction: asc or desc", type: :string]
    ],
    responses: [
      ok: {"Log list", "application/json", MonitorLogSchemas.monitor_log_list()},
      not_found: {"Monitor not found", "application/json", MonitorLogSchemas.error()}
    ]
  )

  def index(conn, %{"monitor_id" => monitor_id} = params) do
    with {:ok, monitor} <- Monitoring.get_monitor(monitor_id) do
      filters = sanitize_filters(params)
      result = Monitoring.list_monitor_logs(monitor, filters)
      render(conn, :index, logs: result)
    end
  end

  operation(:show,
    summary: "Get monitor log",
    description: "Fetch a single log entry with full evidence (headers, snippet, snapshot).",
    parameters: [
      monitor_id: [
        in: :path,
        description: "Monitor UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ],
      id: [
        in: :path,
        description: "Log UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Log details", "application/json", MonitorLogSchemas.monitor_log_response()},
      not_found: {"Log not found", "application/json", MonitorLogSchemas.error()}
    ]
  )

  def show(conn, %{"monitor_id" => monitor_id, "id" => id}) do
    with {:ok, monitor} <- Monitoring.get_monitor(monitor_id) do
      log = Monitoring.get_monitor_log!(id)

      if log.monitor_id == monitor.id do
        render(conn, :show, log: log)
      else
        {:error, :not_found}
      end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp sanitize_filters(params) do
    %{}
    |> maybe_put_integer(params, "page", :page)
    |> maybe_put_integer(params, "page_size", :page_size)
    |> maybe_put_string(params, "status", :status)
    |> maybe_put_string(params, "sort_by", :sort_by)
    |> maybe_put_string(params, "sort_dir", :sort_dir)
  end
end
