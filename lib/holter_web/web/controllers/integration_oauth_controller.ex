defmodule HolterWeb.Web.Integrations.IntegrationOAuthController do
  @moduledoc false

  use HolterWeb, :controller
  use HolterWeb.ControllerTenancy
  use Gettext, backend: HolterWeb.Gettext

  import HolterWeb.Authorization, only: [authorize: 3]

  alias Holter.Integrations.{OAuth, Provider}
  alias Holter.Monitoring

  plug HolterWeb.Plugs.AssignIntegrationWorkspace

  @doc "Redirects the user to the provider's OAuth authorisation page."
  def connect(conn, %{"workspace_slug" => slug, "provider" => provider_str} = params) do
    user = conn.assigns.current_user
    name = Map.get(params, "name", default_name(provider_str))

    with {:ok, provider} <- Provider.cast_provider(provider_str),
         {:ok, workspace} <- Monitoring.get_workspace_by_slug(slug),
         :ok <- authorize(user, :update, workspace),
         {:ok, provider_mod} <- Provider.provider_module(provider),
         state =
           OAuth.generate_state_token(conn, %{
             workspace_id: workspace.id,
             user_id: user.id,
             provider: provider,
             name: name
           }),
         {:ok, url} <- provider_mod.oauth_url(workspace.id, state) do
      redirect(conn, external: url)
    else
      {:error, :unknown_provider} ->
        conn |> put_status(:not_found) |> json(%{error: "unknown provider"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "workspace not found"})

      {:error, :unauthorized} ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      {:error, :not_implemented} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "provider not available"})

      {:error, _reason} ->
        conn |> put_status(:bad_gateway) |> json(%{error: "provider unavailable"})
    end
  end

  @doc "Handles the OAuth callback from the provider."
  def callback(conn, %{"code" => code, "provider" => provider_str}) do
    claims = conn.assigns.oauth_state_claims
    workspace_id = claims.workspace_id
    name = claims[:name] || default_name(provider_str)
    state_token = conn.params["state"]
    {:ok, workspace} = Monitoring.get_workspace(workspace_id)
    {:ok, provider} = Provider.cast_provider(claims.provider)
    {:ok, provider_mod} = Provider.provider_module(provider)

    with {:ok, credentials} <- provider_mod.handle_callback(%{"code" => code}, state_token),
         {:ok, _integration} <-
           OAuth.exchange_and_persist(
             workspace_id,
             %{provider: provider, name: name},
             credentials
           ) do
      conn
      |> put_flash(:info, gettext("Integration connected successfully."))
      |> redirect(to: ~p"/integrations/workspaces/#{workspace.slug}")
    else
      {:error, _reason} ->
        conn
        |> put_flash(:error, gettext("Failed to connect integration. Please try again."))
        |> redirect(to: ~p"/integrations/workspaces/#{workspace.slug}")
    end
  end

  @doc "Revokes OAuth credentials and deletes the integration."
  def disconnect(conn, %{"workspace_slug" => slug, "id" => id}) do
    user = conn.assigns.current_user

    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(slug),
         :ok <- authorize(user, :update, workspace),
         {:ok, integration} <- Holter.Integrations.get_integration(id),
         :ok <- verify_workspace_match(integration, workspace),
         :ok <- revoke_credentials(integration),
         {:ok, _} <- Holter.Integrations.delete_integration(integration) do
      conn
      |> put_flash(:info, gettext("Integration disconnected."))
      |> redirect(to: ~p"/integrations/workspaces/#{slug}")
    else
      {:error, :unauthorized} ->
        conn
        |> put_flash(
          :error,
          gettext("You do not have permission to disconnect this integration.")
        )
        |> redirect(to: ~p"/integrations/workspaces/#{slug}")

      _ ->
        conn
        |> put_flash(:error, gettext("Could not disconnect integration."))
        |> redirect(to: ~p"/integrations/workspaces/#{slug}")
    end
  end

  defp revoke_credentials(integration) do
    case Provider.provider_module(integration.provider) do
      {:ok, provider_mod} -> provider_mod.revoke(integration.credentials_encrypted || %{})
      {:error, :not_implemented} -> :ok
    end
  end

  defp default_name(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp verify_workspace_match(integration, workspace) do
    if integration.workspace_id == workspace.id, do: :ok, else: {:error, :forbidden}
  end
end
