defmodule HolterWeb.Api.EmailChannelSchemas do
  @moduledoc """
  OpenAPI schemas for the standalone email-channel resource (#29).
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "EmailChannel" => email_channel(),
      "EmailChannelResponse" => email_channel_response(),
      "EmailChannelList" => email_channel_list(),
      "EmailChannelCreateRequest" => email_channel_create_request(),
      "EmailChannelUpdateRequest" => email_channel_update_request()
    }
  end

  def email_channel do
    %Schema{
      title: "EmailChannel",
      description: "An email delivery channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        workspace_id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        address: %Schema{type: :string},
        settings: %Schema{type: :object, additionalProperties: true},
        anti_phishing_code: %Schema{
          type: :string,
          description:
            "Visual anti-phishing code printed in every email. Rotate via PUT /api/v1/email_channels/:id/anti_phishing_code."
        },
        verified_at: %Schema{
          type: :string,
          format: :"date-time",
          nullable: true,
          description:
            "Timestamp the address was verified. `null` while pending — alerts to the primary address are blocked until this is set."
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
        :address,
        :settings,
        :anti_phishing_code,
        :verified_at,
        :last_test_dispatched_at,
        :inserted_at,
        :updated_at
      ]
    }
  end

  def email_channel_response do
    %Schema{
      title: "EmailChannelResponse",
      description: "Single email channel response.",
      type: :object,
      properties: %{data: email_channel()},
      required: [:data]
    }
  end

  def email_channel_list do
    %Schema{
      title: "EmailChannelList",
      description: "List of email channels.",
      type: :object,
      properties: %{data: %Schema{type: :array, items: email_channel()}},
      required: [:data]
    }
  end

  def email_channel_create_request do
    %Schema{
      title: "EmailChannelCreateRequest",
      description: "Parameters for creating an email channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        name: %Schema{type: :string, minLength: 1, maxLength: 255},
        address: %Schema{type: :string, minLength: 1, maxLength: 2048},
        settings: %Schema{type: :object, additionalProperties: true, nullable: true}
      },
      required: [:name, :address]
    }
  end

  def email_channel_update_request do
    %Schema{
      title: "EmailChannelUpdateRequest",
      description: "Parameters for updating an email channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        name: %Schema{type: :string, minLength: 1, maxLength: 255},
        address: %Schema{type: :string, minLength: 1, maxLength: 2048},
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
