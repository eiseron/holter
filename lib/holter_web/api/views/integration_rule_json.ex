defmodule HolterWeb.Api.IntegrationRuleJSON do
  @moduledoc """
  JSON view for the integration_rules resource.
  """
  alias Holter.Integrations.Models.IntegrationRule

  def index(%{rules: rules}) do
    %{data: Enum.map(rules, &data/1)}
  end

  def show(%{rule: rule}) do
    %{data: data(rule)}
  end

  defp data(%IntegrationRule{} = rule) do
    %{
      id: rule.id,
      integration_id: rule.integration_id,
      monitor_id: rule.monitor_id,
      event_type: rule.event_type,
      action: rule.action,
      target_type: rule.target_type,
      target_id: rule.target_id,
      target_label: rule.target_label,
      inserted_at: rule.inserted_at,
      updated_at: rule.updated_at
    }
  end
end
