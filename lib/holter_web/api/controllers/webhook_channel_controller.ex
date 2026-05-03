defmodule HolterWeb.Api.WebhookChannelController do
  @moduledoc """
  REST API controller for the standalone webhook-channel resource (#29).
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Holter.Delivery.{Engine, WebhookChannels}
  alias Holter.Monitoring
  alias HolterWeb.Api.WebhookChannelSchemas

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError

  tags(["Webhook Channels"])

  operation(:index,
    summary: "List webhook channels",
    description: "List all webhook channels for a workspace.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    responses: [
      ok:
        {"Webhook channel list", "application/json", WebhookChannelSchemas.webhook_channel_list()},
      not_found: {"Workspace not found", "application/json", WebhookChannelSchemas.error()}
    ]
  )

  def index(conn, %{workspace_slug: workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      channels = WebhookChannels.list(workspace.id)
      render(conn, :index, channels: channels)
    end
  end

  operation(:show,
    summary: "Get webhook channel",
    description: "Fetch a single webhook channel by its UUID.",
    parameters: [
      id: [
        in: :path,
        description: "Webhook channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok:
        {"Webhook channel", "application/json", WebhookChannelSchemas.webhook_channel_response()},
      not_found: {"Channel not found", "application/json", WebhookChannelSchemas.error()}
    ]
  )

  def show(conn, %{id: id}) do
    with {:ok, channel} <- WebhookChannels.get(id) do
      render(conn, :show, channel: channel)
    end
  end

  operation(:create,
    summary: "Create webhook channel",
    description: "Create a new webhook channel for the specified workspace.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    request_body:
      {"Channel parameters", "application/json",
       WebhookChannelSchemas.webhook_channel_create_request()},
    responses: [
      created:
        {"Created channel", "application/json", WebhookChannelSchemas.webhook_channel_response()},
      unprocessable_entity:
        {"Validation error", "application/json", WebhookChannelSchemas.error()}
    ]
  )

  def create(conn, %{workspace_slug: workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         attrs = Map.put(conn.body_params, :workspace_id, workspace.id),
         {:ok, channel} <- WebhookChannels.create(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, channel: channel)
    end
  end

  operation(:update,
    summary: "Update webhook channel",
    description: "Update an existing webhook channel.",
    parameters: [
      id: [
        in: :path,
        description: "Webhook channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    request_body:
      {"Update parameters", "application/json",
       WebhookChannelSchemas.webhook_channel_update_request()},
    responses: [
      ok:
        {"Updated channel", "application/json", WebhookChannelSchemas.webhook_channel_response()},
      not_found: {"Channel not found", "application/json", WebhookChannelSchemas.error()},
      unprocessable_entity:
        {"Validation error", "application/json", WebhookChannelSchemas.error()}
    ]
  )

  def update(conn, %{id: id}) do
    with {:ok, channel} <- WebhookChannels.get(id),
         {:ok, updated} <- WebhookChannels.update(channel, conn.body_params) do
      render(conn, :show, channel: updated)
    end
  end

  operation(:delete,
    summary: "Delete webhook channel",
    description: "Permanently delete a webhook channel.",
    parameters: [
      id: [
        in: :path,
        description: "Webhook channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      no_content: {"Deleted successfully", "application/json", nil},
      not_found: {"Channel not found", "application/json", WebhookChannelSchemas.error()}
    ]
  )

  def delete(conn, %{id: id}) do
    with {:ok, channel} <- WebhookChannels.get(id),
         {:ok, _} <- WebhookChannels.delete(channel) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:ping,
    summary: "Send a test ping",
    description: "Enqueue a test notification to verify the channel is reachable.",
    parameters: [
      webhook_channel_id: [
        in: :path,
        description: "Webhook channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      accepted: {"Ping enqueued", "application/json", nil},
      not_found: {"Channel not found", "application/json", WebhookChannelSchemas.error()},
      too_many_requests:
        {"Test ping rate limited for this channel", "application/json",
         WebhookChannelSchemas.error()}
    ]
  )

  def ping(conn, %{webhook_channel_id: id}) do
    with {:ok, _} <- WebhookChannels.get(id),
         {:ok, _} <- Engine.dispatch_test_webhook(id) do
      send_resp(conn, :accepted, "")
    end
  end

  operation(:rotate_signing_token,
    summary: "Rotate the signing token",
    description:
      "Generate a fresh HMAC signing token. The previous token stops working immediately.",
    parameters: [
      webhook_channel_id: [
        in: :path,
        description: "Webhook channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok:
        {"Channel with rotated signing_token", "application/json",
         WebhookChannelSchemas.webhook_channel_response()},
      not_found: {"Channel not found", "application/json", WebhookChannelSchemas.error()}
    ]
  )

  def rotate_signing_token(conn, %{webhook_channel_id: id}) do
    with {:ok, channel} <- WebhookChannels.get(id),
         {:ok, updated} <- WebhookChannels.regenerate_signing_token(channel) do
      render(conn, :show, channel: updated)
    end
  end
end
