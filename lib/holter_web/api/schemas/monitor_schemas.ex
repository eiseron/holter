defmodule HolterWeb.Api.MonitorSchemas do
  @moduledoc """
  OpenAPI schemas for the Monitor resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "Monitor" => monitor(),
      "MonitorResponse" => monitor_response(),
      "MonitorCreateRequest" => monitor_create_request(),
      "MonitorUpdateRequest" => monitor_update_request(),
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
        timeout_seconds: %Schema{type: :integer, minimum: 1, maximum: 30},
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
        raw_headers: %Schema{type: :string, nullable: true, description: "Raw string of headers"},
        raw_keyword_positive: %Schema{
          type: :string,
          nullable: true,
          description: "Comma-separated positive keywords"
        },
        raw_keyword_negative: %Schema{
          type: :string,
          nullable: true,
          description: "Comma-separated negative keywords"
        },
        last_checked_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_success_at: %Schema{type: :string, format: :"date-time", nullable: true},
        ssl_expires_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :url, :method, :interval_seconds, :timeout_seconds]
    }
  end

  def monitor_response do
    %Schema{
      title: "MonitorResponse",
      description: "A single monitor wrapped in a data envelope.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: monitor()
      },
      required: [:data]
    }
  end

  def monitor_create_request do
    %Schema{
      title: "MonitorCreateRequest",
      description:
        "Parameters for creating a monitor. url, method and interval_seconds are required.",
      type: :object,
      properties: monitor_fields(),
      required: [:url, :method, :interval_seconds]
    }
  end

  def monitor_update_request do
    %Schema{
      title: "MonitorUpdateRequest",
      description: "Parameters for updating a monitor. All fields are optional.",
      type: :object,
      properties: monitor_fields()
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

  defp monitor_fields do
    %{
      url: %Schema{type: :string, format: :uri},
      method: %Schema{
        type: :string,
        enum: ["get", "post", "put", "patch", "delete", "options", "head"]
      },
      interval_seconds: %Schema{type: :integer, minimum: 1, maximum: 86_400},
      timeout_seconds: %Schema{type: :integer, minimum: 1, maximum: 30},
      ssl_ignore: %Schema{type: :boolean, default: false},
      follow_redirects: %Schema{type: :boolean, default: true},
      max_redirects: %Schema{type: :integer, minimum: 1, maximum: 20, default: 5},
      raw_headers: %Schema{type: :string, nullable: true},
      raw_keyword_positive: %Schema{type: :string, nullable: true},
      raw_keyword_negative: %Schema{type: :string, nullable: true},
      body: %Schema{type: :string, nullable: true}
    }
  end
end
