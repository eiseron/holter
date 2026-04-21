defmodule HolterWeb.Api.NotificationChannelController do
  @moduledoc """
  REST API Controller for managing Notification Channels.
  Includes OpenAPI 3.0 operation definitions.
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Holter.Delivery
  alias Holter.Delivery.Engine
  alias Holter.Monitoring
  alias HolterWeb.Api.NotificationChannelSchemas

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError

  tags(["Notification Channels"])

  operation(:index,
    summary: "List notification channels",
    description: "List all notification channels for a workspace.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    responses: [
      ok:
        {"Notification channel list", "application/json",
         NotificationChannelSchemas.notification_channel_list()},
      not_found: {"Workspace not found", "application/json", NotificationChannelSchemas.error()}
    ]
  )

  def index(conn, %{workspace_slug: workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      channels = Delivery.list_channels(workspace.id)
      render(conn, :index, channels: channels)
    end
  end

  operation(:show,
    summary: "Get notification channel",
    description: "Fetch a single notification channel by its UUID.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string],
      id: [
        in: :path,
        description: "Channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok:
        {"Notification channel", "application/json",
         NotificationChannelSchemas.notification_channel_response()},
      not_found: {"Channel not found", "application/json", NotificationChannelSchemas.error()}
    ]
  )

  def show(conn, %{id: id, workspace_slug: _}) do
    with {:ok, channel} <- Delivery.get_channel(id) do
      render(conn, :show, channel: channel)
    end
  end

  operation(:create,
    summary: "Create notification channel",
    description: "Create a new notification channel for the specified workspace.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    request_body:
      {"Channel parameters", "application/json",
       NotificationChannelSchemas.notification_channel_create_request()},
    responses: [
      created:
        {"Created channel", "application/json",
         NotificationChannelSchemas.notification_channel_response()},
      unprocessable_entity:
        {"Validation error", "application/json", NotificationChannelSchemas.error()}
    ]
  )

  def create(conn, %{workspace_slug: workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         attrs = Map.put(conn.body_params, :workspace_id, workspace.id),
         {:ok, channel} <- Delivery.create_channel(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, channel: channel)
    end
  end

  operation(:update,
    summary: "Update notification channel",
    description: "Update an existing notification channel.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string],
      id: [
        in: :path,
        description: "Channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    request_body:
      {"Update parameters", "application/json",
       NotificationChannelSchemas.notification_channel_update_request()},
    responses: [
      ok:
        {"Updated channel", "application/json",
         NotificationChannelSchemas.notification_channel_response()},
      not_found: {"Channel not found", "application/json", NotificationChannelSchemas.error()},
      unprocessable_entity:
        {"Validation error", "application/json", NotificationChannelSchemas.error()}
    ]
  )

  def update(conn, %{id: id, workspace_slug: _}) do
    with {:ok, channel} <- Delivery.get_channel(id),
         {:ok, updated} <- Delivery.update_channel(channel, conn.body_params) do
      render(conn, :show, channel: updated)
    end
  end

  operation(:delete,
    summary: "Delete notification channel",
    description: "Permanently delete a notification channel.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string],
      id: [
        in: :path,
        description: "Channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      no_content: {"Deleted successfully", "application/json", nil},
      not_found: {"Channel not found", "application/json", NotificationChannelSchemas.error()}
    ]
  )

  def delete(conn, %{id: id, workspace_slug: _}) do
    with {:ok, channel} <- Delivery.get_channel(id),
         {:ok, _} <- Delivery.delete_channel(channel) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:test,
    summary: "Send test notification",
    description: "Enqueue a test notification for this channel.",
    parameters: [
      notification_channel_id: [
        in: :path,
        description: "Channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      accepted: {"Test enqueued", "application/json", nil},
      not_found: {"Channel not found", "application/json", NotificationChannelSchemas.error()}
    ]
  )

  def test(conn, %{notification_channel_id: id}) do
    with {:ok, _channel} <- Delivery.get_channel(id),
         {:ok, _job} <- Engine.dispatch_test(id) do
      send_resp(conn, :accepted, "")
    end
  end
end
