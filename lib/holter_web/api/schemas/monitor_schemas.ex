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
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        url: %Schema{type: :string},
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

  def monitor_response do
    %Schema{
      title: "MonitorResponse",
      description: "A single monitor wrapped in a data envelope.",
      type: :object,
      properties: %{
        data: monitor()
      },
      required: [:data]
    }
  end

  defp monitor_fields do
    %{
      url: %Schema{type: :string},
      method: %Schema{
        type: :string,
        enum: ["get", "post", "put", "patch", "delete", "options", "head"]
      },
      interval_seconds: %Schema{type: :integer, minimum: 1, maximum: 86_400},
      timeout_seconds: %Schema{type: :integer, minimum: 1, maximum: 300},
      ssl_ignore: %Schema{type: :boolean, default: false},
      raw_headers: %Schema{type: :string, nullable: true},
      body: %Schema{type: :string, nullable: true},
      raw_keyword_positive: %Schema{type: :string, nullable: true},
      raw_keyword_negative: %Schema{type: :string, nullable: true}
    }
  end

  def monitor_create_request do
    %Schema{
      title: "MonitorCreateRequest",
      description: "Parameters for creating a monitor. url, method and interval_seconds are required.",
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
