defmodule HolterWeb.Api.WebhookChannelSchemas do
  @moduledoc """
  OpenAPI schemas for the standalone webhook-channel resource (#29).
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "WebhookChannel" => webhook_channel(),
      "WebhookChannelResponse" => webhook_channel_response(),
      "WebhookChannelList" => webhook_channel_list(),
      "WebhookChannelCreateRequest" => webhook_channel_create_request(),
      "WebhookChannelUpdateRequest" => webhook_channel_update_request()
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
