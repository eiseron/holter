defmodule HolterWeb.Api.ChannelLogSchemas do
  @moduledoc """
  OpenAPI schemas for the ChannelLog resource.
  """
  alias OpenApiSpex.Schema

  def all do
    %{
      "ChannelLog" => channel_log(),
      "ChannelLogList" => channel_log_list()
    }
  end

  def channel_log do
    %Schema{
      title: "ChannelLog",
      description: "A delivery job log entry for a notification channel.",
      type: :object,
      additionalProperties: false,
      properties: %{
        id: %Schema{type: :integer},
        status: %Schema{type: :string, enum: ["success", "failed"]},
        event: %Schema{type: :string, nullable: true},
        worker: %Schema{type: :string},
        errors: %Schema{type: :array, items: %Schema{type: :string, nullable: true}},
        attempted_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :status, :worker, :inserted_at]
    }
  end

  def channel_log_list do
    %Schema{
      title: "ChannelLogList",
      description: "A paginated list of channel delivery log entries.",
      type: :object,
      additionalProperties: false,
      properties: %{
        data: %Schema{type: :array, items: channel_log()},
        meta: %Schema{
          type: :object,
          additionalProperties: false,
          properties: %{
            page: %Schema{type: :integer},
            page_size: %Schema{type: :integer},
            total_pages: %Schema{type: :integer}
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
        error: %Schema{
          type: :object,
          properties: %{
            code: %Schema{type: :string},
            message: %Schema{type: :string}
          },
          required: [:code, :message]
        }
      },
      required: [:error],
      additionalProperties: false
    }
  end
end
