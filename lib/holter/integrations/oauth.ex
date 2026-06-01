defmodule Holter.Integrations.OAuth do
  @moduledoc false

  alias Holter.Integrations.Engine.CredentialManager
  alias Holter.Integrations.{IntegrationsContext, Provider}

  @state_token_salt "integrations_oauth_state"
  @state_token_max_age 300

  @doc "Signs a state token binding workspace, user, provider, and name together."
  @spec generate_state_token(Plug.Conn.t(), %{
          workspace_id: binary(),
          user_id: binary(),
          provider: atom(),
          name: binary()
        }) :: binary()
  def generate_state_token(conn, %{
        workspace_id: workspace_id,
        user_id: user_id,
        provider: provider,
        name: name
      }) do
    Phoenix.Token.sign(conn, @state_token_salt, %{
      workspace_id: workspace_id,
      user_id: user_id,
      provider: Atom.to_string(provider),
      name: name
    })
  end

  @doc "Verifies a state token. Returns the embedded claims or an error."
  @spec verify_state_token(Plug.Conn.t(), binary()) ::
          {:ok, map()} | {:error, :expired | :invalid}
  def verify_state_token(conn, token) do
    case Phoenix.Token.verify(conn, @state_token_salt, token, max_age: @state_token_max_age) do
      {:ok, claims} -> {:ok, claims}
      {:error, :expired} -> {:error, :expired}
      {:error, _} -> {:error, :invalid}
    end
  end

  @doc "Exchanges credentials and persists a new integration."
  @spec exchange_and_persist(binary(), %{provider: atom(), name: binary()}, map()) ::
          {:ok, term()} | {:error, term()}
  def exchange_and_persist(workspace_id, %{provider: provider, name: name}, credentials) do
    attrs = CredentialManager.build_connect_attrs(workspace_id, provider, credentials)
    IntegrationsContext.create(Map.put(attrs, :name, name))
  end

  @doc """
  Refreshes credentials if they are near expiry or expired.
  Returns {:ok, integration} unchanged when valid, or an updated integration after refresh.
  """
  @spec refresh_if_needed(term(), DateTime.t()) ::
          {:ok, term()} | {:error, :reauth_required | term()}
  def refresh_if_needed(integration, now) do
    status =
      CredentialManager.classify_token_status(
        integration.credentials_encrypted || %{},
        now
      )

    case status do
      :valid ->
        {:ok, integration}

      status when status in [:near_expiry, :expired] ->
        do_refresh(integration, now)
    end
  end

  defp do_refresh(integration, now) do
    case Provider.provider_module(integration.provider) do
      {:error, :not_implemented} -> {:ok, integration}
      {:ok, provider_mod} -> refresh_via_provider(provider_mod, integration, now)
    end
  end

  defp refresh_via_provider(provider_mod, integration, now) do
    case provider_mod.refresh(integration.credentials_encrypted || %{}) do
      {:ok, new_credentials} -> persist_refreshed_credentials(integration, new_credentials)
      {:error, :revoked} -> mark_reauth_required(integration, now)
      {:error, reason} -> {:error, reason}
    end
  end

  defp persist_refreshed_credentials(integration, new_credentials) do
    with {:ok, updated} <-
           IntegrationsContext.update_credentials(integration, %{
             credentials_encrypted: new_credentials
           }) do
      IntegrationsContext.update_status(updated, %{status: :active})
    end
  end

  defp mark_reauth_required(integration, now) do
    IntegrationsContext.update_status(integration, %{
      status: :reauth_required,
      last_error_at: DateTime.truncate(now, :second),
      last_error_reason: "token_revoked"
    })

    {:error, :reauth_required}
  end
end
