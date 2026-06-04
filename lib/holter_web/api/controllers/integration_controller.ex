defmodule HolterWeb.Api.IntegrationController do
  @moduledoc """
  REST API controller for integrations.

  No `:create` action — integrations are minted via OAuth from the browser
  flow (`IntegrationOAuthController`). The API exposes index, show, update
  (name/settings only), and delete (revoke + delete, mirroring the OAuth
  controller's disconnect path).
  """
  use HolterWeb, :controller
  use HolterWeb.ApiTenancy
  use OpenApiSpex.ControllerSpecs

  alias Holter.Integrations
  alias Holter.Integrations.{AuditLogger, Provider}
  alias Holter.Monitoring
  alias Holter.Repo
  alias HolterWeb.Api.IntegrationSchemas
  alias HolterWeb.Plugs.RequireScopePlug

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError
  plug RequireScopePlug, "read:integrations" when action in [:index, :show]
  plug RequireScopePlug, "write:integrations" when action in [:update, :delete]

  tags(["Integrations"])

  operation(:index,
    summary: "List integrations",
    description: "List all integrations connected for a workspace.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string]
    ],
    responses: [
      ok: {"Integration list", "application/json", IntegrationSchemas.integration_list()},
      not_found: {"Workspace not found", "application/json", IntegrationSchemas.error()}
    ]
  )

  def index(conn, %{workspace_slug: workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      integrations = Integrations.list_integrations(workspace.id)
      render(conn, :index, integrations: integrations)
    end
  end

  operation(:show,
    summary: "Get integration",
    description: "Fetch a single integration by its UUID.",
    parameters: [
      id: [
        in: :path,
        description: "Integration UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Integration", "application/json", IntegrationSchemas.integration_response()},
      not_found: {"Integration not found", "application/json", IntegrationSchemas.error()}
    ]
  )

  def show(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, integration} <- Integrations.get_integration(id),
         :ok <- authorize(actor, :read, integration) do
      render(conn, :show, integration: integration)
    end
  end

  operation(:update,
    summary: "Update integration",
    description:
      "Update a connected integration. Only `name` and `settings` are mutable; status and credentials flow through internal logic.",
    parameters: [
      id: [
        in: :path,
        description: "Integration UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    request_body:
      {"Update parameters", "application/json", IntegrationSchemas.integration_update_request()},
    responses: [
      ok: {"Updated integration", "application/json", IntegrationSchemas.integration_response()},
      not_found: {"Integration not found", "application/json", IntegrationSchemas.error()},
      unprocessable_entity: {"Validation error", "application/json", IntegrationSchemas.error()}
    ]
  )

  def update(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, integration} <- Integrations.get_integration(id),
         :ok <- authorize(actor, :update, integration),
         {:ok, updated} <- Integrations.update_integration(integration, conn.body_params) do
      render(conn, :show, integration: updated)
    end
  end

  operation(:delete,
    summary: "Disconnect integration",
    description:
      "Revoke the provider OAuth credentials and delete the integration record. Mirrors the in-app disconnect flow.",
    parameters: [
      id: [
        in: :path,
        description: "Integration UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      no_content: {"Disconnected successfully", "application/json", nil},
      not_found: {"Integration not found", "application/json", IntegrationSchemas.error()}
    ]
  )

  def delete(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, integration} <- Integrations.get_integration(id),
         :ok <- authorize(actor, :delete, integration),
         {:ok, _} <- disconnect_and_audit(integration, actor.id) do
      send_resp(conn, :no_content, "")
    end
  end

  defp disconnect_and_audit(integration, actor_id) do
    revoke_credentials(integration)

    Repo.transaction(fn ->
      case Integrations.delete_integration(integration) do
        {:ok, _} ->
          AuditLogger.log_disconnected(actor_id, integration.workspace_id, integration.provider)
          :ok

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp revoke_credentials(integration) do
    case Provider.provider_module(integration.provider) do
      {:ok, provider_mod} -> provider_mod.revoke(integration.credentials_encrypted || %{})
      {:error, :not_implemented} -> :ok
    end
  end
end
