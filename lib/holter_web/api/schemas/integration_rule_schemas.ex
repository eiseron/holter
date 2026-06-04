defmodule HolterWeb.Api.IntegrationRuleSchemas do
  @moduledoc """
  OpenAPI schemas for integration rules (rules attaching an Integration to
  a Monitor + event + target).
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "IntegrationRule" => integration_rule(),
      "IntegrationRuleResponse" => integration_rule_response(),
      "IntegrationRuleList" => integration_rule_list(),
      "IntegrationRuleCreateRequest" => integration_rule_create_request(),
      "IntegrationRuleUpdateRequest" => integration_rule_update_request()
    }
  end

  def integration_rule do
    %Schema{
      title: "IntegrationRule",
      description:
        "Binds an Integration to a Monitor + event + external target. Without a rule, an Integration is connected but inert.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        integration_id: %Schema{type: :string, format: :uuid},
        monitor_id: %Schema{type: :string, format: :uuid},
        event_type: %Schema{
          type: :string,
          enum: ["incident_opened", "incident_resolved", "monitor_paused", "monitor_resumed"]
        },
        action: %Schema{
          type: :string,
          enum: ["pause_campaign", "resume_campaign", "pause_ad_set", "resume_ad_set"]
        },
        target_type: %Schema{
          type: :string,
          enum: ["campaign", "ad_set", "channel", "component", "project", "ticket", "page"]
        },
        target_id: %Schema{type: :string},
        target_label: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [
        :id,
        :integration_id,
        :monitor_id,
        :event_type,
        :action,
        :target_type,
        :target_id,
        :inserted_at,
        :updated_at
      ]
    }
  end

  def integration_rule_response do
    %Schema{
      title: "IntegrationRuleResponse",
      type: :object,
      properties: %{data: integration_rule()},
      required: [:data]
    }
  end

  def integration_rule_list do
    %Schema{
      title: "IntegrationRuleList",
      type: :object,
      properties: %{data: %Schema{type: :array, items: integration_rule()}},
      required: [:data]
    }
  end

  def integration_rule_create_request do
    %Schema{
      title: "IntegrationRuleCreateRequest",
      description: "Parameters for creating a rule under an integration.",
      type: :object,
      additionalProperties: false,
      properties: %{
        monitor_id: %Schema{type: :string, format: :uuid},
        event_type: %Schema{
          type: :string,
          enum: ["incident_opened", "incident_resolved", "monitor_paused", "monitor_resumed"]
        },
        action: %Schema{
          type: :string,
          enum: ["pause_campaign", "resume_campaign", "pause_ad_set", "resume_ad_set"]
        },
        target_id: %Schema{type: :string, minLength: 1, maxLength: 255},
        target_label: %Schema{type: :string, maxLength: 255, nullable: true}
      },
      required: [:monitor_id, :event_type, :action, :target_id]
    }
  end

  def integration_rule_update_request do
    %Schema{
      title: "IntegrationRuleUpdateRequest",
      description: "Parameters for updating a rule.",
      type: :object,
      additionalProperties: false,
      properties: %{
        event_type: %Schema{
          type: :string,
          enum: ["incident_opened", "incident_resolved", "monitor_paused", "monitor_resumed"]
        },
        action: %Schema{
          type: :string,
          enum: ["pause_campaign", "resume_campaign", "pause_ad_set", "resume_ad_set"]
        },
        target_id: %Schema{type: :string, minLength: 1, maxLength: 255},
        target_label: %Schema{type: :string, maxLength: 255, nullable: true}
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
