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
      ],
      page: [
        in: :query,
        description: "Page number",
        schema: %OpenApiSpex.Schema{type: :integer, default: 1}
      ],
      page_size: [
        in: :query,
        description: "Items per page",
        schema: %OpenApiSpex.Schema{type: :integer, default: 30}
      ],
      sort_by: [
        in: :query,
        description: "Sort column (date, uptime_percent, avg_latency_ms, total_downtime_minutes)",
        type: :string
      ],
      sort_dir: [in: :query, description: "Sort direction: asc or desc", type: :string]
    ],
    responses: [
      ok: {"Daily metric list", "application/json", DailyMetricSchemas.daily_metric_list()},
      not_found: {"Monitor not found", "application/json", DailyMetricSchemas.error()}
    ]
  )

  def index(conn, %{"monitor_id" => monitor_id} = params) do
    with {:ok, monitor} <- Monitoring.get_monitor(monitor_id) do
      filters = sanitize_filters(params)
      result = Monitoring.list_daily_metrics(monitor.id, filters)
      render(conn, :index, result: result)
    end
  end

  defp sanitize_filters(params) do
    %{}
    |> maybe_put_integer(params, "page", :page)
    |> maybe_put_integer(params, "page_size", :page_size)
    |> maybe_put_string(params, "sort_by", :sort_by)
    |> maybe_put_string(params, "sort_dir", :sort_dir)
  end

  defp maybe_put_integer(acc, params, key, atom_key) do
    case Map.get(params, key) do
      val when is_binary(val) ->
        case Integer.parse(val) do
          {int, ""} -> Map.put(acc, atom_key, int)
          _ -> acc
        end

      val when is_integer(val) ->
        Map.put(acc, atom_key, val)

      _ ->
        acc
    end
  end

  defp maybe_put_string(acc, params, key, atom_key) do
    case Map.get(params, key) do
      val when is_binary(val) and val != "" -> Map.put(acc, atom_key, val)
      _ -> acc
    end
  end
end
