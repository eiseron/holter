defmodule HolterWeb.Api.MonitorSchemas do
  @moduledoc """
  OpenAPI schemas for the Monitor resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "Monitor" => monitor(),
      "MonitorRequest" => monitor_request(),
      "MonitorList" => monitor_list(),
      "Error" => error()
    }
  end

  def monitor do
    %Schema{
      title: "Monitor",
      description: "A monitoring target for HTTP/HTTPS/SSL checks.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        url: %Schema{type: :string, format: :uri},
        method: %Schema{
          type: :string,
          enum: ["get", "post", "put", "patch", "delete", "options", "head"]
        },
        interval_seconds: %Schema{type: :integer, minimum: 1, maximum: 86_400},
        timeout_seconds: %Schema{type: :integer, minimum: 1, maximum: 300},
        health_status: %Schema{
          type: :string,
          enum: ["up", "down", "degraded", "compromised", "unknown"]
        },
        logical_state: %Schema{type: :string, enum: ["active", "paused", "archived"]},
        last_checked_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :url, :method, :interval_seconds, :timeout_seconds]
    }
  end

  def monitor_request do
    %Schema{
      title: "MonitorRequest",
      description: "Parameters for creating or updating a monitor.",
      type: :object,
      properties: %{
        url: %Schema{type: :string, format: :uri},
        method: %Schema{
          type: :string,
          enum: ["get", "post", "put", "patch", "delete", "options", "head"]
        },
        interval_seconds: %Schema{type: :integer, minimum: 1, maximum: 86_400},
        timeout_seconds: %Schema{type: :integer, minimum: 1, maximum: 300},
        ssl_ignore: %Schema{type: :boolean, default: false},
        raw_headers: %Schema{type: :string, nullable: true},
        raw_keyword_positive: %Schema{type: :string, nullable: true},
        raw_keyword_negative: %Schema{type: :string, nullable: true}
      },
      required: [:url, :method, :interval_seconds]
    }
  end

  def monitor_list do
    %Schema{
      title: "MonitorList",
      description: "A list of monitors with metadata.",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: monitor()},
        meta: %Schema{
          type: :object,
          properties: %{
            page: %Schema{type: :integer},
            page_size: %Schema{type: :integer},
            total: %Schema{type: :integer}
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
      properties: %{
        errors: %Schema{
          type: :object,
          additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
        }
      }
    }
  end
end
