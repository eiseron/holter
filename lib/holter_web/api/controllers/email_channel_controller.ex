defmodule HolterWeb.Api.EmailChannelController do
  @moduledoc """
  REST API controller for the standalone email-channel resource (#29).
  """
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Holter.Delivery.{EmailChannels, Engine}
  alias Holter.Monitoring
  alias HolterWeb.Api.EmailChannelSchemas

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError

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
    description:
      "Create a new email channel for the specified workspace. The channel is created in an unverified state and a verification email is sent to the address.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    request_body:
      {"Channel parameters", "application/json",
       EmailChannelSchemas.email_channel_create_request()},
    responses: [
      created:
        {"Created channel", "application/json", EmailChannelSchemas.email_channel_response()},
      unprocessable_entity: {"Validation error", "application/json", EmailChannelSchemas.error()}
    ]
  )

  def create(conn, %{workspace_slug: workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug),
         attrs = Map.put(conn.body_params, :workspace_id, workspace.id),
         {:ok, channel} <- EmailChannels.create(attrs) do
      maybe_send_verification(channel)

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
    with {:ok, channel} <- EmailChannels.get(id),
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
    with {:ok, channel} <- EmailChannels.get(id),
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
    with {:ok, _} <- EmailChannels.get(id),
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
    with {:ok, channel} <- EmailChannels.get(id),
         {:ok, updated} <- EmailChannels.regenerate_anti_phishing_code(channel) do
      render(conn, :show, channel: updated)
    end
  end

  defp maybe_send_verification(%{verified_at: %DateTime{}}), do: :ok
  defp maybe_send_verification(channel), do: EmailChannels.send_verification(channel)
end
