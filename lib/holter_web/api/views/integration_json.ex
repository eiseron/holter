defmodule HolterWeb.Api.IntegrationJSON do
  @moduledoc """
  JSON view for the integrations resource.

  Credentials are never serialised — they live encrypted on the model and
  are read only by the dispatcher path.
  """
  alias Holter.Integrations.Models.Integration

  def index(%{integrations: integrations}) do
    %{data: Enum.map(integrations, &data/1)}
  end

  def show(%{integration: integration}) do
    %{data: data(integration)}
  end

  defp data(%Integration{} = integration) do
    %{
      id: integration.id,
      workspace_id: integration.workspace_id,
      provider: integration.provider,
      name: integration.name,
      status: integration.status,
      settings: integration.settings,
      last_sync_at: integration.last_sync_at,
      last_error_at: integration.last_error_at,
      last_error_reason: integration.last_error_reason,
      inserted_at: integration.inserted_at,
      updated_at: integration.updated_at
    }
  end
end
