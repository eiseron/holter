defmodule Holter.Integrations do
  @moduledoc """
  Public API for the Integrations domain.

  Delegates to domain-specific coordinators. Callers must stamp the
  tenant before calling functions that touch workspace-scoped data.
  """

  alias Holter.Integrations.IntegrationEventsContext
  alias Holter.Integrations.IntegrationsContext
  alias Holter.Integrations.Models.Integration
  alias Holter.Integrations.Models.IntegrationEvent

  defdelegate list_integrations(workspace_id), to: IntegrationsContext, as: :list

  defdelegate list_active_integrations_for_event(workspace_id, event),
    to: IntegrationsContext,
    as: :list_active_for_event

  defdelegate get_integration(id), to: IntegrationsContext, as: :get
  defdelegate get_integration!(id), to: IntegrationsContext, as: :get!

  defdelegate get_integration_by_workspace_and_provider(workspace_id, provider),
    to: IntegrationsContext,
    as: :get_by_workspace_and_provider

  defdelegate create_integration(attrs), to: IntegrationsContext, as: :create
  defdelegate update_integration(integration, attrs), to: IntegrationsContext, as: :update

  defdelegate update_integration_status(integration, attrs),
    to: IntegrationsContext,
    as: :update_status

  defdelegate update_integration_credentials(integration, attrs),
    to: IntegrationsContext,
    as: :update_credentials

  defdelegate delete_integration(integration), to: IntegrationsContext, as: :delete
  defdelegate change_integration(integration, attrs \\ %{}), to: IntegrationsContext, as: :change

  defdelegate log_integration_event(attrs), to: IntegrationEventsContext, as: :log_event!

  defdelegate list_integration_events(integration_id, opts \\ []),
    to: IntegrationEventsContext,
    as: :list_events

  def integration_providers, do: Integration.providers()
  def integration_statuses, do: Integration.statuses()
  def integration_event_directions, do: IntegrationEvent.directions()
  def integration_event_statuses, do: IntegrationEvent.statuses()
end
