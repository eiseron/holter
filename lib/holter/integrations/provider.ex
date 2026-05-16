defmodule Holter.Integrations.Provider do
  @moduledoc """
  Behaviour all integration provider modules must implement.

  Each provider implements OAuth, dispatch, and lifecycle callbacks.
  Register new providers in `providers/0` as implementations land.
  """

  @doc "Resolves the module that implements the Provider behaviour for a given provider atom."
  @spec provider_module(atom()) :: {:ok, module()} | {:error, :not_implemented}
  def provider_module(provider) when is_atom(provider) do
    case Map.fetch(providers(), provider) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, :not_implemented}
    end
  end

  defp providers do
    Application.get_env(:holter, :integration_providers, %{})
  end

  @type credentials :: map()
  @type event :: String.t()
  @type action :: atom()
  @type dispatch_result :: :ok | {:error, term()}

  @callback display_name() :: String.t()
  @callback oauth_url(workspace_id :: binary(), state :: binary()) ::
              {:ok, String.t()} | {:error, term()}
  @callback handle_callback(params :: map(), state :: binary()) ::
              {:ok, credentials()} | {:error, term()}
  @callback refresh(credentials()) :: {:ok, credentials()} | {:error, term()}
  @callback dispatch(integration :: term(), event :: event(), payload :: map()) ::
              dispatch_result()
  @callback revoke(credentials()) :: :ok | {:error, term()}
  @callback supported_actions() :: [action()]
  @callback supported_events() :: [event()]
end
