defmodule Holter.Integrations.Provider do
  @moduledoc """
  Behaviour all integration provider modules must implement.

  Each provider implements OAuth, action encoding, and lifecycle
  callbacks. `encode/3` is a clause per supported action that turns a
  resolved target into a `Request`; the `ActionRunner` runs it and skips
  unsupported actions. Register new providers in `providers/0` as
  implementations land.
  """

  alias Holter.Integrations.Models.Integration
  alias Holter.Integrations.Request

  @doc "Safely casts a string to a known provider atom. Returns error for unknown providers."
  @spec cast_provider(binary()) :: {:ok, atom()} | {:error, :unknown_provider}
  def cast_provider(provider_str) when is_binary(provider_str) do
    known = Integration.providers()

    case Enum.find(known, &(Atom.to_string(&1) == provider_str)) do
      nil -> {:error, :unknown_provider}
      provider -> {:ok, provider}
    end
  end

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

  @callback display_name() :: String.t()
  @callback oauth_url(workspace_id :: binary(), state :: binary()) ::
              {:ok, String.t()} | {:error, term()}
  @callback handle_callback(params :: map(), state :: binary()) ::
              {:ok, credentials()} | {:error, term()}
  @callback refresh(credentials()) :: {:ok, credentials()} | {:error, term()}
  @callback encode(action :: String.t(), target :: map(), integration :: term()) ::
              {:ok, Request.t()} | :unsupported | {:error, term()}
  @callback revoke(credentials()) :: :ok | {:error, term()}
  @callback supported_actions() :: [action()]
  @callback supported_events() :: [event()]
  @callback action_label(action()) :: String.t()
  @callback validate_webhook_signature(raw_body :: binary(), headers :: map(), secret :: binary()) ::
              :ok | {:error, :invalid_signature | :timestamp_expired}
  @callback handle_inbound_webhook(integration :: term(), params :: map()) ::
              :ok | {:error, term()}
  @callback category() :: atom()
  @callback icon() :: String.t()

  @optional_callbacks [
    validate_webhook_signature: 3,
    handle_inbound_webhook: 2,
    category: 0,
    icon: 0,
    action_label: 1
  ]
end
