defmodule HolterWeb.Api.IntegrationEventSchemas do
  @moduledoc """
  OpenAPI schemas for the integration_events resource (append-only audit log).
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "IntegrationEvent" => integration_event(),
      "IntegrationEventResponse" => integration_event_response(),
      "IntegrationEventList" => integration_event_list()
    }
  end

  def integration_event do
    %Schema{
      title: "IntegrationEvent",
      description:
        "Append-only record of an integration dispatch or webhook receipt. Payload is redacted before storage.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        integration_id: %Schema{type: :string, format: :uuid},
        direction: %Schema{type: :string, enum: ["outbound", "inbound"]},
        action: %Schema{type: :string},
        target: %Schema{type: :string, nullable: true},
        payload_redacted: %Schema{type: :object, additionalProperties: true},
        status: %Schema{
          type: :string,
          enum: ["success", "failed", "rate_limited", "retried"]
        },
        duration_ms: %Schema{type: :integer, nullable: true},
        occurred_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [
        :id,
        :integration_id,
        :direction,
        :action,
        :status,
        :occurred_at,
        :inserted_at
      ]
    }
  end

  def integration_event_response do
    %Schema{
      title: "IntegrationEventResponse",
      type: :object,
      properties: %{data: integration_event()},
      required: [:data]
    }
  end

  def integration_event_list do
    %Schema{
      title: "IntegrationEventList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: integration_event()},
        meta: %Schema{
          type: :object,
          properties: %{
            page: %Schema{type: :integer},
            page_size: %Schema{type: :integer},
            total_pages: %Schema{type: :integer}
          },
          required: [:page, :page_size, :total_pages]
        }
      },
      required: [:data, :meta]
    }
  end

  def error do
    %Schema{
      title: "Error",
      type: :object,
      properties: %{
        error: %Schema{
          type: :object,
          properties: %{
            code: %Schema{type: :string},
            message: %Schema{type: :string}
          }
        }
      }
    }
  end
end
