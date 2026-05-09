defmodule HolterWeb.Api.WorkspaceController do
  @moduledoc """
  REST API Controller for Workspace details.
  Includes OpenAPI 3.0 operation definitions.
  """
  use HolterWeb, :controller
  use HolterWeb.ApiTenancy
  use OpenApiSpex.ControllerSpecs

  alias Holter.Monitoring
  alias HolterWeb.Api.WorkspaceSchemas
  alias HolterWeb.Plugs.RequireScopePlug

  action_fallback HolterWeb.Api.FallbackController

  plug RequireScopePlug, "read:workspaces" when action in [:show]

  tags(["Workspaces"])

  operation(:show,
    summary: "Get workspace",
    description: "Fetch a workspace by its slug.",
    parameters: [
      workspace_slug: [
        in: :path,
        description: "Workspace slug",
        type: :string,
        example: "eiseron"
      ]
    ],
    responses: [
      ok: {"Workspace details", "application/json", WorkspaceSchemas.workspace()},
      not_found: {"Workspace not found", "application/json", WorkspaceSchemas.error()}
    ]
  )

  def show(conn, %{"workspace_slug" => workspace_slug}) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      render(conn, :show, workspace: workspace)
    end
  end
end
