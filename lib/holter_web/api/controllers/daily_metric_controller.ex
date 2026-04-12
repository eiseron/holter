defmodule HolterWeb.Api.DailyMetricController do
  @moduledoc """
  REST API Controller for Daily Metrics.
  Includes OpenAPI 3.0 operation definitions.
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Holter.Monitoring
  alias HolterWeb.Api.DailyMetricSchemas

  action_fallback HolterWeb.Api.FallbackController

  tags(["Metrics"])

  operation(:index,
    summary: "List daily metrics",
    description: "List aggregated daily uptime and performance metrics for a monitor.",
    parameters: [
      monitor_id: [
        in: :path,
        description: "Monitor UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Daily metric list", "application/json", DailyMetricSchemas.daily_metric_list()},
      not_found: {"Monitor not found", "application/json", DailyMetricSchemas.error()}
    ]
  )

  def index(conn, %{"monitor_id" => monitor_id}) do
    with {:ok, monitor} <- Monitoring.get_monitor(monitor_id) do
      metrics = Monitoring.list_daily_metrics(monitor.id)
      render(conn, :index, metrics: metrics)
    end
  end
end
