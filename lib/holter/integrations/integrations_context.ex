defmodule Holter.Integrations.IntegrationsContext do
  @moduledoc """
  Coordinator for the `integrations` table.

  Public functions assume the caller has already stamped the tenant
  via one of the entry-point macros (`HolterWeb.LiveTenancy`,
  `HolterWeb.ApiTenancy`, or
  `Holter.Monitoring.Workers.WorkspaceScopedWorker`). The RLS policy
  `tenant_isolation` (keyed on `app.current_workspace_id`) reads the
  session var set by the boundary stamp.
  """

  import Ecto.Query

  alias Holter.Integrations.Models.Integration
  alias Holter.Repo

  def list(workspace_id) do
    Integration
    |> where([i], i.workspace_id == ^workspace_id)
    |> order_by([i], asc: i.provider)
    |> Repo.all()
  end

  def get(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %Integration{} = integration <- Repo.get(Integration, id) do
      {:ok, integration}
    else
      _ -> {:error, :not_found}
    end
  end

  def get!(id), do: Repo.get!(Integration, id)

  def list_by_ids(ids) when is_list(ids) do
    Integration
    |> where([i], i.id in ^ids)
    |> Repo.all()
  end

  def get_by_workspace_and_provider(workspace_id, provider) do
    Integration
    |> where(
      [i],
      i.workspace_id == ^workspace_id and i.provider == ^provider and i.status == :active
    )
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  end

  def create(attrs \\ %{}) do
    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Integration{} = integration, attrs) do
    integration
    |> Integration.changeset(attrs)
    |> Repo.update()
  end

  def update_status(%Integration{} = integration, attrs) do
    integration
    |> Integration.status_changeset(attrs)
    |> Repo.update()
  end

  def update_credentials(%Integration{} = integration, attrs) do
    integration
    |> Integration.credentials_changeset(attrs)
    |> Repo.update()
  end

  def delete(%Integration{} = integration) do
    Repo.delete(integration)
  end

  def change(%Integration{} = integration, attrs \\ %{}) do
    Integration.changeset(integration, attrs)
  end
end
