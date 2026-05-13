defmodule HolterWeb.Api.EmailChannelController do
  @moduledoc """
  REST API controller for the standalone email-channel resource (#29).
  """
  use HolterWeb, :controller
  use HolterWeb.ApiTenancy
  use OpenApiSpex.ControllerSpecs

  alias Holter.Delivery.{EmailChannels, Engine}
  alias Holter.Delivery.Models.EmailChannel
  alias Holter.Monitoring
  alias HolterWeb.Api.EmailChannelSchemas
  alias HolterWeb.Plugs.RequireScopePlug

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError
  plug RequireScopePlug, "read:channels" when action in [:index, :show]

  plug RequireScopePlug,
       "write:channels" when action in [:create, :update, :delete, :rotate_anti_phishing_code]

  plug RequireScopePlug, "ping:channels" when action in [:ping]

  tags(["Email Channels"])

  operation(:index,
    summary: "List email channels",
    description: "List all email channels for a workspace.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    responses: [
      ok: {"Email channel list", "application/json", EmailChannelSchemas.email_channel_list()},
      not_found: {"Workspace not found", "application/json", EmailChannelSchemas.error()}
    ]
  )

  def index(conn, %{workspace_slug: workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      channels = EmailChannels.list(workspace.id)
      render(conn, :index, channels: channels)
    end
  end

  operation(:show,
    summary: "Get email channel",
    description: "Fetch a single email channel by its UUID.",
    parameters: [
      id: [
        in: :path,
        description: "Email channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Email channel", "application/json", EmailChannelSchemas.email_channel_response()},
      not_found: {"Channel not found", "application/json", EmailChannelSchemas.error()}
    ]
  )

  def show(conn, %{id: id}) do
    with {:ok, channel} <- EmailChannels.get(id) do
      render(conn, :show, channel: channel)
    end
  end

  operation(:create,
    summary: "Create email channel",
    description: """
    Create a new email channel for the specified workspace. Recipients are
    managed on a sibling resource and carry their own per-address
    verification.

    Returns 422 with `error.code = "channel_quota_reached"` when the
    workspace's combined webhook + email channel count has reached
    `max_channels`. The cap is set on `Delivery.WorkspaceProfile` and
    is editable from the workspace settings page.
    """,
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    request_body:
      {"Channel parameters", "application/json",
       EmailChannelSchemas.email_channel_create_request()},
    responses: [
      created:
        {"Created channel", "application/json", EmailChannelSchemas.email_channel_response()},
      unprocessable_entity:
        {"Validation error or `channel_quota_reached`", "application/json",
         EmailChannelSchemas.error()}
    ]
  )

  def create(conn, %{workspace_slug: workspace_slug}) do
    actor = conn.assigns.current_user

    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         :ok <- authorize(actor, :create, {EmailChannel, workspace}),
         attrs = Map.put(conn.body_params, :workspace_id, workspace.id),
         {:ok, channel} <- EmailChannels.create(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, channel: channel)
    end
  end

  operation(:update,
    summary: "Update email channel",
    description: "Update an existing email channel.",
    parameters: [
      id: [
        in: :path,
        description: "Email channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    request_body:
      {"Update parameters", "application/json",
       EmailChannelSchemas.email_channel_update_request()},
    responses: [
      ok: {"Updated channel", "application/json", EmailChannelSchemas.email_channel_response()},
      not_found: {"Channel not found", "application/json", EmailChannelSchemas.error()},
      unprocessable_entity: {"Validation error", "application/json", EmailChannelSchemas.error()}
    ]
  )

  def update(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, channel} <- EmailChannels.get(id),
         :ok <- authorize(actor, :update, channel),
         {:ok, updated} <- EmailChannels.update(channel, conn.body_params) do
      render(conn, :show, channel: updated)
    end
  end

  operation(:delete,
    summary: "Delete email channel",
    description: "Permanently delete an email channel.",
    parameters: [
      id: [
        in: :path,
        description: "Email channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      no_content: {"Deleted successfully", "application/json", nil},
      not_found: {"Channel not found", "application/json", EmailChannelSchemas.error()}
    ]
  )

  def delete(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, channel} <- EmailChannels.get(id),
         :ok <- authorize(actor, :delete, channel),
         {:ok, _} <- EmailChannels.delete(channel) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:ping,
    summary: "Send a test ping",
    description: "Enqueue a test notification to verify the channel is reachable.",
    parameters: [
      email_channel_id: [
        in: :path,
        description: "Email channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      accepted: {"Ping enqueued", "application/json", nil},
      not_found: {"Channel not found", "application/json", EmailChannelSchemas.error()},
      unprocessable_entity:
        {"No verified recipient on this channel", "application/json", EmailChannelSchemas.error()},
      too_many_requests:
        {"Test ping rate limited for this channel", "application/json",
         EmailChannelSchemas.error()}
    ]
  )

  def ping(conn, %{email_channel_id: id}) do
    actor = conn.assigns.current_user

    with {:ok, channel} <- EmailChannels.get(id),
         :ok <- authorize(actor, :update, channel),
         {:ok, _} <- Engine.dispatch_test_email(id) do
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

  operation(:rotate_anti_phishing_code,
    summary: "Rotate the anti-phishing code",
    description:
      "Generate a fresh anti-phishing code. The next email through this channel will carry the new value.",
    parameters: [
      email_channel_id: [
        in: :path,
        description: "Email channel UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok:
        {"Channel with rotated anti_phishing_code", "application/json",
         EmailChannelSchemas.email_channel_response()},
      not_found: {"Channel not found", "application/json", EmailChannelSchemas.error()}
    ]
  )

  def rotate_anti_phishing_code(conn, %{email_channel_id: id}) do
    actor = conn.assigns.current_user

    with {:ok, channel} <- EmailChannels.get(id),
         :ok <- authorize(actor, :update, channel),
         {:ok, updated} <- EmailChannels.regenerate_anti_phishing_code(channel) do
      render(conn, :show, channel: updated)
    end
  end
end
