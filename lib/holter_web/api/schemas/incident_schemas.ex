defmodule HolterWeb.Api.IncidentSchemas do
  @moduledoc """
  OpenAPI schemas for the Incident resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "Incident" => incident(),
      "IncidentResponse" => incident_response(),
      "IncidentList" => incident_list(),
      "Error" => error()
    }
  end

  def incident do
    %Schema{
      title: "Incident",
      description: "A detected downtime, defacement, or SSL expiry incident for a monitor.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        type: %Schema{type: :string, enum: ["downtime", "defacement", "ssl_expiry"]},
        started_at: %Schema{type: :string, format: :"date-time"},
        resolved_at: %Schema{type: :string, format: :"date-time", nullable: true},
        duration_seconds: %Schema{type: :integer, nullable: true},
        root_cause: %Schema{type: :string, nullable: true},
        monitor_snapshot: %Schema{type: :object, nullable: true, additionalProperties: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :type, :started_at]
    }
  end

  def incident_response do
    %Schema{
      title: "IncidentResponse",
      description: "Response body for a single incident.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: incident()
      }
    }
  end

  def incident_list do
    %Schema{
      title: "IncidentList",
      description: "A paginated list of incidents ordered by start time descending.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: %Schema{type: :array, items: incident()},
        meta: %Schema{
          type: :object,
          additionalProperties: false,
          properties: %{
            page: %Schema{type: :integer},
            page_size: %Schema{type: :integer},
            total: %Schema{type: :integer}
          },
          required: [:page, :page_size, :total]
        }
      },
      required: [:data, :meta]
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
