defmodule HolterWeb.Api.WebhookChannelSchemas do
  @moduledoc """
  OpenAPI schemas for the standalone webhook-channel resource (#29).
  """
  alias OpenApiSpex.{MediaType, Operation, PathItem, Reference, RequestBody, Response, Schema}

  def all do
    %{
      "WebhookChannel" => webhook_channel(),
      "WebhookChannelResponse" => webhook_channel_response(),
      "WebhookChannelList" => webhook_channel_list(),
      "WebhookChannelCreateRequest" => webhook_channel_create_request(),
      "WebhookChannelUpdateRequest" => webhook_channel_update_request(),
      "MonitorSummary" => monitor_summary(),
      "IncidentSummary" => incident_summary(),
      "ChannelSummary" => channel_summary(),
      "WebhookIncidentDispatch" => webhook_incident_dispatch(),
      "WebhookTestPingDispatch" => webhook_test_ping_dispatch(),
      "WebhookDispatch" => webhook_dispatch()
    }
  end

  def webhook_channel do
    %Schema{
      title: "WebhookChannel",
      description: "A webhook delivery channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        workspace_id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        url: %Schema{type: :string},
        settings: %Schema{type: :object, additionalProperties: true},
        signing_token: %Schema{
          type: :string,
          description:
            "HMAC-SHA256 signing key. Sensitive — keep private. Rotate via PUT /api/v1/webhook_channels/:id/signing_token."
        },
        last_test_dispatched_at: %Schema{
          type: :string,
          format: :"date-time",
          nullable: true,
          description: "Timestamp of the most recent test ping. Used for cooldown gating."
        },
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [
        :id,
        :workspace_id,
        :name,
        :url,
        :settings,
        :signing_token,
        :last_test_dispatched_at,
        :inserted_at,
        :updated_at
      ]
    }
  end

  def webhook_channel_response do
    %Schema{
      title: "WebhookChannelResponse",
      description: "Single webhook channel response.",
      type: :object,
      properties: %{data: webhook_channel()},
      required: [:data]
    }
  end

  def webhook_channel_list do
    %Schema{
      title: "WebhookChannelList",
      description: "List of webhook channels.",
      type: :object,
      properties: %{data: %Schema{type: :array, items: webhook_channel()}},
      required: [:data]
    }
  end

  def webhook_channel_create_request do
    %Schema{
      title: "WebhookChannelCreateRequest",
      description: "Parameters for creating a webhook channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        name: %Schema{type: :string, minLength: 1, maxLength: 255},
        url: %Schema{type: :string, minLength: 1, maxLength: 2048},
        settings: %Schema{type: :object, additionalProperties: true, nullable: true}
      },
      required: [:name, :url]
    }
  end

  def webhook_channel_update_request do
    %Schema{
      title: "WebhookChannelUpdateRequest",
      description: "Parameters for updating a webhook channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        name: %Schema{type: :string, minLength: 1, maxLength: 255},
        url: %Schema{type: :string, minLength: 1, maxLength: 2048},
        settings: %Schema{type: :object, additionalProperties: true, nullable: true}
      }
    }
  end

  def monitor_summary do
    %Schema{
      title: "MonitorSummary",
      description: "Lightweight monitor reference included in dispatch payloads.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        url: %Schema{type: :string},
        health_status: %Schema{
          type: :string,
          enum: ["up", "down", "degraded", "compromised", "unknown"]
        }
      },
      required: [:id, :url, :health_status]
    }
  end

  def incident_summary do
    %Schema{
      title: "IncidentSummary",
      description: "Lightweight incident reference included in dispatch payloads.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        type: %Schema{type: :string, enum: ["downtime", "defacement", "ssl_expiry"]},
        started_at: %Schema{type: :string, format: :"date-time"},
        resolved_at: %Schema{type: :string, format: :"date-time", nullable: true},
        duration_seconds: %Schema{type: :integer, nullable: true},
        root_cause: %Schema{type: :string, nullable: true}
      },
      required: [:id, :type, :started_at, :resolved_at, :duration_seconds, :root_cause]
    }
  end

  def channel_summary do
    %Schema{
      title: "ChannelSummary",
      description: "Lightweight channel reference included in test-ping payloads.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        type: %Schema{type: :string, enum: ["webhook", "email"]}
      },
      required: [:id, :name, :type]
    }
  end

  def webhook_incident_dispatch do
    %Schema{
      title: "WebhookIncidentDispatch",
      description: "Payload posted when a monitor incident opens or resolves.",
      type: :object,
      properties: %{
        version: %Schema{type: :string, enum: ["1.0"]},
        event: %Schema{type: :string, enum: ["monitor_down", "monitor_up"]},
        timestamp: %Schema{type: :string, format: :"date-time"},
        monitor: monitor_summary(),
        incident: incident_summary()
      },
      required: [:version, :event, :timestamp, :monitor, :incident]
    }
  end

  def webhook_test_ping_dispatch do
    %Schema{
      title: "WebhookTestPingDispatch",
      description: "Payload posted when the customer triggers a test ping.",
      type: :object,
      properties: %{
        version: %Schema{type: :string, enum: ["1.0"]},
        event: %Schema{type: :string, enum: ["test_ping"]},
        timestamp: %Schema{type: :string, format: :"date-time"},
        channel: channel_summary()
      },
      required: [:version, :event, :timestamp, :channel]
    }
  end

  def webhook_dispatch do
    %Schema{
      title: "WebhookDispatch",
      description: """
      Outbound payload Holter POSTs to the webhook URL when an incident opens or
      resolves, or when the customer triggers a test ping. Discriminated on
      `event`. Requests carry the `X-Holter-Signature: t=<unix>,v1=<hex>` header
      (HMAC-SHA256 of `<timestamp>.<body>` keyed by the channel `signing_token`).
      """,
      oneOf: [
        %Reference{"$ref": "#/components/schemas/WebhookIncidentDispatch"},
        %Reference{"$ref": "#/components/schemas/WebhookTestPingDispatch"}
      ],
      discriminator: %OpenApiSpex.Discriminator{
        propertyName: "event",
        mapping: %{
          "monitor_down" => "#/components/schemas/WebhookIncidentDispatch",
          "monitor_up" => "#/components/schemas/WebhookIncidentDispatch",
          "test_ping" => "#/components/schemas/WebhookTestPingDispatch"
        }
      }
    }
  end

  def dispatch_callback do
    %{
      "webhookDispatch" => %{
        "{$request.body#/url}" => %PathItem{
          post: %Operation{
            operationId: "webhookDispatch",
            summary: "Outbound dispatch to the customer's webhook URL",
            description: """
            Holter POSTs this payload to the URL registered on the channel when a
            monitor opens or resolves an incident, or when the customer triggers a
            test ping. Signed via the `X-Holter-Signature: t=<unix>,v1=<hex>`
            header (HMAC-SHA256 of `<timestamp>.<body>` keyed by `signing_token`).
            Respond 2xx to acknowledge; non-2xx triggers Oban retry with backoff.
            """,
            requestBody: %RequestBody{
              description: "Dispatch payload",
              required: true,
              content: %{
                "application/json" => %MediaType{
                  schema: %Reference{"$ref": "#/components/schemas/WebhookDispatch"}
                }
              }
            },
            responses: %{
              "2XX" => %Response{description: "Delivery acknowledged."},
              "default" => %Response{description: "Non-2xx triggers retry."}
            }
          }
        }
      }
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
