defmodule HolterWeb.Plugs.AssignIntegrationWorkspace do
  @moduledoc """
  Resolves the integration request's workspace and assigns it as
  `:current_workspace` so `HolterWeb.ControllerTenancy` can stamp the
  tenant for the whole action body.

  The workspace source depends on the route:

    * connect/disconnect carry `:workspace_slug` in the path;
    * the OAuth callback carries the workspace inside the signed state
      token, already decoded into `:oauth_state_claims` by
      `HolterWeb.Plugs.IntegrationOAuthPlug`.

  When neither source resolves a workspace the plug is a no-op; the
  action keeps its own resolution and returns the appropriate 404/redirect.
  """

  import Plug.Conn

  alias Holter.Monitoring

  def init(opts), do: opts

  def call(conn, _opts) do
    case resolve_workspace(conn) do
      {:ok, workspace} -> assign(conn, :current_workspace, workspace)
      _ -> conn
    end
  end

  defp resolve_workspace(%{assigns: %{oauth_state_claims: %{workspace_id: workspace_id}}}),
    do: Monitoring.get_workspace(workspace_id)

  defp resolve_workspace(%{path_params: %{"workspace_slug" => slug}}),
    do: Monitoring.get_workspace_by_slug(slug)

  defp resolve_workspace(_conn), do: :error
end
