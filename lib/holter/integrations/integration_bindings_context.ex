defmodule Holter.Integrations.IntegrationBindingsContext do
  @moduledoc """
  Coordinator for the `integration_bindings` table.

  A binding amarra uma Integration a um Monitor com um evento específico e
  um target externo (campaign, ad_set, channel, etc.). Sem nenhum binding,
  uma Integration está conectada mas inerte — não dispara nada quando um
  incident chega.

  Public functions assume the caller has already stamped the tenant via
  one of the entry-point macros (`HolterWeb.LiveTenancy`,
  `HolterWeb.ApiTenancy`, or `Holter.Monitoring.Workers.WorkspaceScopedWorker`).
  RLS is indirect via the integrations FK.
  """

  import Ecto.Query

  alias Holter.Integrations.Models.IntegrationBinding
  alias Holter.Repo

  def list_for_integration(integration_id) do
    IntegrationBinding
    |> where([b], b.integration_id == ^integration_id)
    |> order_by([b], asc: b.event_type, asc: b.action, asc: b.target_id)
    |> Repo.all()
  end

  def list_active_for_monitor_event(monitor_id, event_type)
      when is_binary(event_type) do
    IntegrationBinding
    |> where([b], b.monitor_id == ^monitor_id and b.event_type == ^event_type)
    |> Repo.all()
  end

  def get(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %IntegrationBinding{} = binding <- Repo.get(IntegrationBinding, id) do
      {:ok, binding}
    else
      _ -> {:error, :not_found}
    end
  end

  def get!(id), do: Repo.get!(IntegrationBinding, id)

  def create(attrs \\ %{}) do
    %IntegrationBinding{}
    |> IntegrationBinding.changeset(attrs)
    |> Repo.insert()
  end

  def delete(%IntegrationBinding{} = binding) do
    Repo.delete(binding)
  end

  def group_by_integration(bindings) when is_list(bindings) do
    Enum.group_by(bindings, & &1.integration_id)
  end
end
