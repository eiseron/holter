defmodule HolterWeb.Api.IntegrationRuleController do
  @moduledoc """
  REST API controller for integration rules (the rule rows that wire an
  integration to monitor events).

  Authorization is delegated to the parent `Integration` policy — modifying
  a rule is functionally modifying the integration's behaviour, so the
  same admin-only gate applies.
  """
  use HolterWeb, :controller
  use HolterWeb.ApiTenancy
  use OpenApiSpex.ControllerSpecs

  alias Holter.Integrations
  alias HolterWeb.Api.IntegrationRuleSchemas
  alias HolterWeb.Plugs.RequireScopePlug

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError
  plug RequireScopePlug, "read:integrations" when action in [:index, :show]
  plug RequireScopePlug, "write:integrations" when action in [:create, :update, :delete]

  tags(["Integration Rules"])

  operation(:index,
    summary: "List rules for an integration",
    description: "List all rules attached to the given integration.",
    parameters: [
      integration_id: [
        in: :path,
        description: "Integration UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Rule list", "application/json", IntegrationRuleSchemas.integration_rule_list()},
      not_found: {"Integration not found", "application/json", IntegrationRuleSchemas.error()}
    ]
  )

  def index(conn, %{integration_id: integration_id}) do
    actor = conn.assigns.current_user

    with {:ok, integration} <- Integrations.get_integration(integration_id),
         :ok <- authorize(actor, :read, integration) do
      rules = Integrations.list_rules_for_integration(integration.id)
      render(conn, :index, rules: rules)
    end
  end

  operation(:create,
    summary: "Create rule under an integration",
    description: "Attach a new rule to an integration.",
    parameters: [
      integration_id: [
        in: :path,
        description: "Integration UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    request_body:
      {"Rule parameters", "application/json",
       IntegrationRuleSchemas.integration_rule_create_request()},
    responses: [
      created:
        {"Created rule", "application/json", IntegrationRuleSchemas.integration_rule_response()},
      not_found: {"Integration not found", "application/json", IntegrationRuleSchemas.error()},
      unprocessable_entity:
        {"Validation error", "application/json", IntegrationRuleSchemas.error()}
    ]
  )

  def create(conn, %{integration_id: integration_id}) do
    actor = conn.assigns.current_user

    with {:ok, integration} <- Integrations.get_integration(integration_id),
         :ok <- authorize(actor, :update, integration),
         :ok <- verify_monitor_in_workspace(conn.body_params, integration.workspace_id),
         attrs = Map.put(conn.body_params, :integration_id, integration.id),
         {:ok, rule} <- Integrations.create_integration_rule(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, rule: rule)
    end
  end

  operation(:show,
    summary: "Get rule",
    description: "Fetch a single rule by its UUID.",
    parameters: [
      id: [
        in: :path,
        description: "Rule UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Rule", "application/json", IntegrationRuleSchemas.integration_rule_response()},
      not_found: {"Rule not found", "application/json", IntegrationRuleSchemas.error()}
    ]
  )

  def show(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, rule} <- Integrations.get_integration_rule(id),
         {:ok, integration} <- Integrations.get_integration(rule.integration_id),
         :ok <- authorize(actor, :read, integration) do
      render(conn, :show, rule: rule)
    end
  end

  operation(:update,
    summary: "Update rule",
    description: "Update an existing rule.",
    parameters: [
      id: [
        in: :path,
        description: "Rule UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    request_body:
      {"Update parameters", "application/json",
       IntegrationRuleSchemas.integration_rule_update_request()},
    responses: [
      ok:
        {"Updated rule", "application/json", IntegrationRuleSchemas.integration_rule_response()},
      not_found: {"Rule not found", "application/json", IntegrationRuleSchemas.error()},
      unprocessable_entity:
        {"Validation error", "application/json", IntegrationRuleSchemas.error()}
    ]
  )

  def update(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, rule} <- Integrations.get_integration_rule(id),
         {:ok, integration} <- Integrations.get_integration(rule.integration_id),
         :ok <- authorize(actor, :update, integration),
         :ok <- verify_monitor_in_workspace(conn.body_params, integration.workspace_id),
         {:ok, updated} <- Integrations.update_integration_rule(rule, conn.body_params) do
      render(conn, :show, rule: updated)
    end
  end

  operation(:delete,
    summary: "Delete rule",
    description: "Permanently delete a rule.",
    parameters: [
      id: [
        in: :path,
        description: "Rule UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      no_content: {"Deleted successfully", "application/json", nil},
      not_found: {"Rule not found", "application/json", IntegrationRuleSchemas.error()}
    ]
  )

  def delete(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, rule} <- Integrations.get_integration_rule(id),
         {:ok, integration} <- Integrations.get_integration(rule.integration_id),
         :ok <- authorize(actor, :delete, integration),
         {:ok, _} <- Integrations.delete_integration_rule(rule) do
      send_resp(conn, :no_content, "")
    end
  end

  defp verify_monitor_in_workspace(%{monitor_id: monitor_id}, workspace_id)
       when not is_nil(monitor_id) do
    monitor_belongs_to_workspace(monitor_id, workspace_id)
  end

  defp verify_monitor_in_workspace(_body_params, _workspace_id), do: :ok

  defp monitor_belongs_to_workspace(monitor_id, workspace_id) do
    case Holter.Monitoring.get_monitor(monitor_id) do
      {:ok, %{workspace_id: ^workspace_id}} -> :ok
      _ -> {:error, :not_found}
    end
  end
end
