defmodule HolterWeb.Api.DailyMetricSchemas do
  @moduledoc """
  OpenAPI schemas for the DailyMetric resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "DailyMetric" => daily_metric(),
      "DailyMetricList" => daily_metric_list(),
      "Error" => error()
    }
  end

  def daily_metric do
    %Schema{
      title: "DailyMetric",
      description: "Aggregated daily uptime and performance metrics for a monitor.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        date: %Schema{type: :string, format: :date},
        uptime_percent: %Schema{type: :number},
        avg_latency_ms: %Schema{type: :integer},
        total_downtime_minutes: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :date, :uptime_percent, :avg_latency_ms, :total_downtime_minutes]
    }
  end

  def daily_metric_list do
    %Schema{
      title: "DailyMetricList",
      description: "A list of daily metric entries ordered by date descending.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: %Schema{type: :array, items: daily_metric()}
      }
    }
  end

  def error do
    %Schema{
      title: "Error",
      description: "Standard error response.",
      type: :object,
      properties: %{
        error: %Schema{
          type: :object,
          properties: %{
            code: %Schema{type: :string, description: "Machine-readable error code (slug)."},
            message: %Schema{type: :string, description: "Human-readable error message."},
            details: %Schema{
              type: :object,
              description: "Optional additional error details (e.g. validation errors)."
            }
          },
          required: [:code, :message]
        }
      },
      required: [:error],
      additionalProperties: false
    }
  end
end
