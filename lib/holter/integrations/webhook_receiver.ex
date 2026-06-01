defmodule Holter.Integrations.WebhookReceiver do
  @moduledoc """
  Coordinator for inbound provider webhooks. Resolves the workspace and
  integration under the tenant context, then persists an inbound
  IntegrationEvent only when the request's signature was verified — an
  unverified request is acknowledged but never written, so a caller
  cannot amplify storage by posting to a known webhook URL.
  """

  alias Holter.Integrations.IntegrationEventsContext
  alias Holter.Integrations.IntegrationsContext
  alias Holter.Integrations.Provider
  alias Holter.Monitoring
  alias Holter.Repo.Tenant

  @spec process_inbound(binary(), %{
          provider: atom(),
          params: map(),
          verified?: boolean()
        }) :: {:ok, :processed | :ignored} | {:error, :not_found}
  def process_inbound(workspace_slug, %{} = request) do
    now = DateTime.utc_now()

    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(workspace_slug) do
      Tenant.with_workspace!(workspace.id, fn ->
        process_for_workspace(workspace, request, now)
      end)
    end
  end

  defp process_for_workspace(workspace, %{provider: provider} = request, now) do
    with {:ok, integration} <-
           IntegrationsContext.get_by_workspace_and_provider(workspace.id, provider) do
      handle_inbound(integration, request, now)
    end
  end

  defp handle_inbound(_integration, %{verified?: false}, _now), do: {:ok, :ignored}

  defp handle_inbound(integration, %{provider: provider, params: params}, now) do
    invoke_provider_handler(provider, integration, params)
    log_inbound_event(integration, now)
    {:ok, :processed}
  end

  defp invoke_provider_handler(provider, integration, params) do
    with {:ok, provider_mod} <- Provider.provider_module(provider),
         true <- function_exported?(provider_mod, :handle_inbound_webhook, 2) do
      provider_mod.handle_inbound_webhook(integration, params)
    else
      _ -> :ok
    end
  end

  defp log_inbound_event(integration, now) do
    IntegrationEventsContext.log_event!(%{
      integration_id: integration.id,
      direction: :inbound,
      action: "webhook_received",
      status: :success,
      occurred_at: DateTime.truncate(now, :second)
    })
  end
end
