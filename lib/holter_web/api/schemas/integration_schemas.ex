defmodule HolterWeb.Api.IntegrationSchemas do
  @moduledoc """
  OpenAPI schemas for the integrations resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "Integration" => integration(),
      "IntegrationResponse" => integration_response(),
      "IntegrationList" => integration_list(),
      "IntegrationUpdateRequest" => integration_update_request()
    }
  end

  def integration do
    %Schema{
      title: "Integration",
      description:
        "A workspace-scoped third-party integration (provider OAuth connection). Status and credentials are managed by internal flows; only `name` and `settings` are user-editable from the API.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        workspace_id: %Schema{type: :string, format: :uuid},
        provider: %Schema{
          type: :string,
          description: "Provider key (e.g. google_ads, meta_ads, slack)."
        },
        name: %Schema{type: :string},
        status: %Schema{
          type: :string,
          enum: ["active", "reauth_required", "rate_limited", "disabled", "provider_down"]
        },
        settings: %Schema{type: :object, additionalProperties: true},
        last_sync_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_error_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_error_reason: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [
        :id,
        :workspace_id,
        :provider,
        :name,
        :status,
        :settings,
        :inserted_at,
        :updated_at
      ]
    }
  end

  def integration_response do
    %Schema{
      title: "IntegrationResponse",
      description: "Single integration response.",
      type: :object,
      properties: %{data: integration()},
      required: [:data]
    }
  end

  def integration_list do
    %Schema{
      title: "IntegrationList",
      description: "List of integrations.",
      type: :object,
      properties: %{data: %Schema{type: :array, items: integration()}},
      required: [:data]
    }
  end

  def integration_update_request do
    %Schema{
      title: "IntegrationUpdateRequest",
      description:
        "Parameters for updating an integration. Only `name` and `settings` are user-mutable; status and credentials flow through internal logic (OAuth, dispatcher feedback).",
      type: :object,
      additionalProperties: false,
      properties: %{
        name: %Schema{type: :string, minLength: 1, maxLength: 255},
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
