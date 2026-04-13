defmodule HolterWeb.Api.MonitorLogSchemas do
  @moduledoc """
  OpenAPI schemas for the MonitorLog resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "MonitorLog" => monitor_log(),
      "MonitorLogResponse" => monitor_log_response(),
      "MonitorLogList" => monitor_log_list()
    }
  end

  def monitor_log_response do
    %Schema{
      title: "MonitorLogResponse",
      description: "Response containing a single monitor log entry.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: monitor_log()
      },
      required: [:data]
    }
  end

  def monitor_log do
    %Schema{
      title: "MonitorLog",
      description: "A single check result for a monitor.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        status: %Schema{
          type: :string,
          enum: ["up", "down", "degraded", "compromised", "unknown"]
        },
        status_code: %Schema{type: :integer, nullable: true},
        latency_ms: %Schema{type: :integer, nullable: true},
        region: %Schema{type: :string, nullable: true},
        response_snippet: %Schema{type: :string, nullable: true},
        response_headers: %Schema{type: :object, nullable: true, additionalProperties: true},
        response_ip: %Schema{type: :string, nullable: true},
        error_message: %Schema{type: :string, nullable: true},
        redirect_count: %Schema{type: :integer, nullable: true},
        last_redirect_url: %Schema{type: :string, nullable: true},
        monitor_snapshot: %Schema{type: :object, nullable: true, additionalProperties: true},
        checked_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :status, :checked_at]
    }
  end

  def monitor_log_list do
    %Schema{
      title: "MonitorLogList",
      description: "A paginated list of monitor log entries.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: %Schema{type: :array, items: monitor_log()},
        meta: %Schema{
          type: :object,
          additionalProperties: false,
          properties: %{
            page: %Schema{type: :integer},
            page_size: %Schema{type: :integer},
            total_pages: %Schema{type: :integer}
          }
        }
      }
    }
  end

  def error do
    %Schema{
      title: "Error",
      description: "Standard error response.",
      type: :object,
      additionalProperties: false,
      properties: %{
        errors: %Schema{
          type: :object,
          additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
        }
      }
    }
  end
end
