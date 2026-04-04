defmodule Holter.MonitoringFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Holter.Monitoring` context.
  """

  def organization_fixture(attrs \\ %{}) do
    {:ok, organization} =
      attrs
      |> Enum.into(%{
        name: "Test Organization",
        slug: "test-organization-#{System.unique_integer([:positive])}"
      })
      |> Holter.Monitoring.create_organization()

    organization
  end

  def monitor_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    org_id =
      cond do
        id = attrs[:organization_id] -> id
        id = attrs["organization_id"] -> id
        org = attrs[:organization] -> org.id
        true -> organization_fixture().id
      end

    attrs =
      %{
        url: "https://example.com",
        method: "get",
        interval_seconds: 60,
        timeout_seconds: 30,
        organization_id: org_id
      }
      |> Map.merge(attrs)

    {:ok, monitor} = Holter.Monitoring.create_monitor(attrs)

    monitor
  end
end
