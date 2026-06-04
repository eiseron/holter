defmodule Holter.Integrations.IntegrationRulesContext do
  @moduledoc """
  Coordinator for the `integration_rules` table.

  A rule binds an Integration to a Monitor with a specific event and an
  external target (campaign, ad_set, channel, etc.). Without any rules,
  an Integration is connected but inert — nothing fires when an incident
  arrives.

  Public functions assume the caller has already stamped the tenant via
  one of the entry-point macros (`HolterWeb.LiveTenancy`,
  `HolterWeb.ApiTenancy`, or `Holter.Monitoring.Workers.WorkspaceScopedWorker`).
  RLS is indirect via the integrations FK.
  """

  import Ecto.Query

  alias Holter.Integrations.Models.IntegrationRule
  alias Holter.Repo

  def list_for_integration(integration_id) do
    IntegrationRule
    |> where([b], b.integration_id == ^integration_id)
    |> order_by([b], asc: b.event_type, asc: b.action, asc: b.target_id)
    |> Repo.all()
  end

  def list_active_for_monitor_event(monitor_id, event_type)
      when is_binary(event_type) do
    IntegrationRule
    |> where([b], b.monitor_id == ^monitor_id and b.event_type == ^event_type)
    |> Repo.all()
  end

  def get(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %IntegrationRule{} = rule <- Repo.get(IntegrationRule, id) do
      {:ok, rule}
    else
      _ -> {:error, :not_found}
    end
  end

  def get!(id), do: Repo.get!(IntegrationRule, id)

  def create(attrs \\ %{}) do
    %IntegrationRule{}
    |> IntegrationRule.changeset(attrs)
    |> Repo.insert()
  end

  def delete(%IntegrationRule{} = rule) do
    Repo.delete(rule)
  end

  def group_by_integration(rules) when is_list(rules) do
    Enum.group_by(rules, & &1.integration_id)
  end
end
