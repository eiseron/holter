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
    description: "List all notification channels for a workspace. Optionally filter by `type`.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string],
      type: [
        in: :query,
        description: "Restrict results to channels of this type.",
        required: false,
        schema: %OpenApiSpex.Schema{type: :string, enum: ["webhook", "email"]}
      ]
    ],
    responses: [
      ok:
        {"Notification channel list", "application/json",
         NotificationChannelSchemas.notification_channel_list()},
      not_found: {"Workspace not found", "application/json", NotificationChannelSchemas.error()}
    ]
  )

  def index(conn, %{workspace_slug: workspace_slug} = params) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      filters = %{type: parse_type_filter(params[:type])}
      channels = Delivery.list_channels(workspace.id, filters)
      render(conn, :index, channels: channels)
    end
  end

  operation(:show,
    summary: "Get notification channel",
    description: "Fetch a single notification channel by its UUID.",
    parameters: [
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

  def show(conn, %{id: id}) do
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
      maybe_send_email_channel_verification(channel)

      conn
      |> put_status(:created)
      |> render(:show, channel: channel)
    end
  end

  operation(:update,
    summary: "Update notification channel",
    description: "Update an existing notification channel.",
    parameters: [
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

  def update(conn, %{id: id}) do
    with {:ok, channel} <- Delivery.get_channel(id),
         {:ok, updated} <- Delivery.update_channel(channel, conn.body_params) do
      render(conn, :show, channel: updated)
    end
  end

  operation(:delete,
    summary: "Delete notification channel",
    description: "Permanently delete a notification channel.",
    parameters: [
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

  def delete(conn, %{id: id}) do
    with {:ok, channel} <- Delivery.get_channel(id),
         {:ok, _} <- Delivery.delete_channel(channel) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:ping,
    summary: "Send a channel ping",
    description: "Enqueue a test notification to verify the channel is reachable.",
    parameters: [
      notification_channel_id: [
        in: :path,
        description: "Channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      accepted: {"Ping enqueued", "application/json", nil},
      not_found: {"Channel not found", "application/json", NotificationChannelSchemas.error()},
      unprocessable_entity:
        {"No verified recipient on this channel", "application/json",
         NotificationChannelSchemas.error()},
      too_many_requests:
        {"Test ping rate limited for this channel", "application/json",
         NotificationChannelSchemas.error()}
    ]
  )

  def ping(conn, %{notification_channel_id: id}) do
    with {:ok, _channel} <- Delivery.get_channel(id),
         {:ok, _job} <- Engine.dispatch_test(id) do
      send_resp(conn, :accepted, "")
    else
      {:error, :no_verified_recipients} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "no_verified_recipients",
            message: "No verified recipient on this channel"
          }
        })

      other ->
        other
    end
  end

  operation(:rotate_signing_token,
    summary: "Rotate the webhook signing token",
    description:
      "Generate a fresh HMAC signing token for a webhook channel. The previous token stops working at the next dispatch.",
    parameters: [
      notification_channel_id: [
        in: :path,
        description: "Channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok:
        {"Channel with rotated signing_token", "application/json",
         NotificationChannelSchemas.notification_channel_response()},
      not_found: {"Channel not found", "application/json", NotificationChannelSchemas.error()},
      unprocessable_entity:
        {"Channel is not a webhook channel", "application/json",
         NotificationChannelSchemas.error()}
    ]
  )

  def rotate_signing_token(conn, %{notification_channel_id: id}) do
    with {:ok, channel} <- Delivery.get_channel(id),
         {:ok, updated} <- Delivery.regenerate_signing_token(channel) do
      render(conn, :show, channel: updated)
    end
  end

  operation(:rotate_anti_phishing_code,
    summary: "Rotate the email anti-phishing code",
    description:
      "Generate a fresh anti-phishing code for an email channel. The next email through this channel will carry the new value.",
    parameters: [
      notification_channel_id: [
        in: :path,
        description: "Channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok:
        {"Channel with rotated anti_phishing_code", "application/json",
         NotificationChannelSchemas.notification_channel_response()},
      not_found: {"Channel not found", "application/json", NotificationChannelSchemas.error()},
      unprocessable_entity:
        {"Channel is not an email channel", "application/json",
         NotificationChannelSchemas.error()}
    ]
  )

  def rotate_anti_phishing_code(conn, %{notification_channel_id: id}) do
    with {:ok, channel} <- Delivery.get_channel(id),
         {:ok, updated} <- Delivery.regenerate_anti_phishing_code(channel) do
      render(conn, :show, channel: updated)
    end
  end

  defp parse_type_filter("webhook"), do: :webhook
  defp parse_type_filter("email"), do: :email
  defp parse_type_filter(_), do: nil

  defp maybe_send_email_channel_verification(%{type: :email} = channel) do
    Delivery.send_email_channel_verification(channel)
  end

  defp maybe_send_email_channel_verification(_), do: :ok
end
