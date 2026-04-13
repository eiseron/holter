defmodule HolterWeb.Api.WorkspaceSchemas do
  @moduledoc """
  OpenAPI schemas for the Workspace resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "Workspace" => workspace(),
      "Error" => error()
    }
  end

  def workspace do
    %Schema{
      title: "WorkspaceResponse",
      description: "Response containing a single workspace.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: %Schema{
          title: "Workspace",
          description: "A workspace that groups monitors together.",
          type: :object,
          additionalProperties: false,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            name: %Schema{type: :string},
            slug: %Schema{type: :string},
            retention_days: %Schema{type: :integer, minimum: 1},
            max_monitors: %Schema{type: :integer, minimum: 1},
            min_interval_seconds: %Schema{type: :integer, minimum: 10},
            inserted_at: %Schema{type: :string, format: :"date-time"},
            updated_at: %Schema{type: :string, format: :"date-time"}
          },
          required: [:id, :name, :slug, :retention_days, :max_monitors, :min_interval_seconds]
        }
      },
      required: [:data]
    }
  end

  def error do
    %Schema{
      title: "Error",
      description: "Standard error response.",
      type: :object,
      additionalProperties: false,
      properties: %{
        errors: %Schema{
          type: :object,
          additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
        }
      }
    }
  end
end
