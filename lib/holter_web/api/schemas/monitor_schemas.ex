defmodule HolterWeb.Api.MonitorSchemas do
  @moduledoc """
  OpenAPI schemas for the Monitor resource.
  """
  alias OpenApiSpex.Schema

  def monitor_response do
    %Schema{
      title: "MonitorResponse",
      description: "Response containing a single monitor.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: monitor()
      },
      required: [:data]
    }
  end

  def all do
    %{
      "Monitor" => monitor(),
      "MonitorResponse" => monitor_response(),
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
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        url: %Schema{type: :string, format: :uri},
        method: %Schema{
          type: :string,
          enum: ["get", "post", "head", "put", "patch", "delete", "options"]
        },
        interval_seconds: %Schema{type: :integer, minimum: 1, maximum: 86_400},
        timeout_seconds: %Schema{type: :integer, minimum: 1, maximum: 300},
        health_status: %Schema{
          type: :string,
          enum: ["up", "down", "degraded", "compromised", "unknown"]
        },
        logical_state: %Schema{type: :string, enum: ["active", "paused", "archived"]},
        ssl_ignore: %Schema{type: :boolean, default: false},
        follow_redirects: %Schema{type: :boolean, default: true},
        max_redirects: %Schema{type: :integer, minimum: 1, maximum: 20, default: 5},
        headers: %Schema{type: :object, nullable: true, additionalProperties: true},
        body: %Schema{type: :string, nullable: true},
        keyword_positive: %Schema{type: :array, items: %Schema{type: :string}},
        keyword_negative: %Schema{type: :array, items: %Schema{type: :string}},
        last_checked_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_success_at: %Schema{type: :string, format: :"date-time", nullable: true},
        ssl_expires_at: %Schema{type: :string, format: :"date-time", nullable: true},
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
      additionalProperties: false,
      properties: %{
        url: %Schema{type: :string, format: :uri},
        method: %Schema{
          type: :string,
          enum: ["get", "post", "put", "patch", "delete", "options", "head"]
        },
        interval_seconds: %Schema{type: :integer, minimum: 1, maximum: 86_400},
        timeout_seconds: %Schema{type: :integer, minimum: 1, maximum: 300},
        ssl_ignore: %Schema{type: :boolean, default: false},
        follow_redirects: %Schema{type: :boolean, default: true},
        max_redirects: %Schema{type: :integer, minimum: 1, maximum: 20, default: 5},
        raw_headers: %Schema{type: :string, nullable: true},
        raw_keyword_positive: %Schema{type: :string, nullable: true},
        raw_keyword_negative: %Schema{type: :string, nullable: true},
        body: %Schema{type: :string, nullable: true}
      },
      required: [:url, :method, :interval_seconds]
    }
  end

  def monitor_list do
    %Schema{
      title: "MonitorList",
      description: "A list of monitors with metadata.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: %Schema{type: :array, items: monitor()},
        meta: %Schema{
          type: :object,
          additionalProperties: false,
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
