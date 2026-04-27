defmodule HolterWeb.Api.NotificationChannelSchemas do
  @moduledoc """
  OpenAPI schemas for the NotificationChannel resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "NotificationChannel" => notification_channel(),
      "NotificationChannelResponse" => notification_channel_response(),
      "NotificationChannelList" => notification_channel_list(),
      "NotificationChannelCreateRequest" => notification_channel_create_request(),
      "NotificationChannelUpdateRequest" => notification_channel_update_request(),
      "WebhookChannel" => webhook_channel(),
      "EmailChannel" => email_channel()
    }
  end

  def notification_channel do
    %Schema{
      title: "NotificationChannel",
      description:
        "A notification delivery channel. Carries common fields plus exactly one populated subtype object — `webhook_channel` xor `email_channel`. The other is `null`.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        workspace_id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        type: %Schema{type: :string, enum: ["email", "webhook"]},
        webhook_channel: %{webhook_channel() | nullable: true},
        email_channel: %{email_channel() | nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [
        :id,
        :workspace_id,
        :name,
        :type,
        :webhook_channel,
        :email_channel,
        :inserted_at,
        :updated_at
      ]
    }
  end

  def webhook_channel do
    %Schema{
      title: "WebhookChannel",
      description: "Webhook-specific configuration.",
      type: :object,
      additionalProperties: false,
      properties: %{
        url: %Schema{type: :string},
        settings: %Schema{type: :object, additionalProperties: true},
        signing_token: %Schema{
          type: :string,
          description:
            "HMAC-SHA256 signing key. Sensitive — keep private. Rotate via PUT /api/v1/notification_channels/:id/signing_token."
        }
      },
      required: [:url, :settings, :signing_token]
    }
  end

  def email_channel do
    %Schema{
      title: "EmailChannel",
      description: "Email-specific configuration.",
      type: :object,
      additionalProperties: false,
      properties: %{
        address: %Schema{type: :string},
        settings: %Schema{type: :object, additionalProperties: true},
        anti_phishing_code: %Schema{
          type: :string,
          description:
            "Visual anti-phishing code printed in every email. Rotate via PUT /api/v1/notification_channels/:id/anti_phishing_code."
        }
      },
      required: [:address, :settings, :anti_phishing_code]
    }
  end

  def notification_channel_response do
    %Schema{
      title: "NotificationChannelResponse",
      description: "Single notification channel response.",
      type: :object,
      properties: %{
        data: notification_channel()
      },
      required: [:data]
    }
  end

  def notification_channel_list do
    %Schema{
      title: "NotificationChannelList",
      description: "Paginated list of notification channels.",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: notification_channel()}
      },
      required: [:data]
    }
  end

  def notification_channel_create_request do
    %Schema{
      title: "NotificationChannelCreateRequest",
      description: "Parameters for creating a notification channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        name: %Schema{type: :string, minLength: 1, maxLength: 255},
        type: %Schema{type: :string, enum: ["email", "webhook"]},
        target: %Schema{type: :string, minLength: 1, maxLength: 2048},
        settings: %Schema{type: :object, additionalProperties: true, nullable: true}
      },
      required: [:name, :type, :target]
    }
  end

  def notification_channel_update_request do
    %Schema{
      title: "NotificationChannelUpdateRequest",
      description: "Parameters for updating a notification channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        name: %Schema{type: :string, minLength: 1, maxLength: 255},
        target: %Schema{type: :string, minLength: 1, maxLength: 2048},
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
