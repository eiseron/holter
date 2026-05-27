defmodule Holter.IntegrationsFixtures do
  @moduledoc """
  Test helpers for creating Integration and IntegrationEvent entities.
  """

  alias Holter.Integrations.IntegrationBindingsContext
  alias Holter.Integrations.IntegrationEventsContext
  alias Holter.Integrations.IntegrationsContext

  def integration_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    workspace_id =
      cond do
        id = attrs[:workspace_id] -> id
        id = attrs["workspace_id"] -> id
        ws = attrs[:workspace] -> ws.id
        true -> workspace_id_from_fixtures()
      end

    base_attrs = Map.drop(attrs, [:workspace_id, "workspace_id", :workspace, "workspace"])

    attrs =
      Enum.into(base_attrs, %{
        workspace_id: workspace_id,
        provider: :google_ads,
        name: "Google Ads #{System.unique_integer([:positive])}",
        status: :active,
        credentials_encrypted: %{
          "access_token" => "test_access_token",
          "refresh_token" => "test_refresh_token",
          "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600))
        },
        settings: %{"campaign_ids" => ["gads-12345"]},
        subscribed_events: ["incident_opened", "incident_resolved"]
      })

    {:ok, integration} = IntegrationsContext.create(attrs)
    integration
  end

  def integration_event_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    integration_id =
      cond do
        id = attrs[:integration_id] ->
          id

        id = attrs["integration_id"] ->
          id

        ig = attrs[:integration] ->
          ig.id

        true ->
          raise ArgumentError,
                "integration_event_fixture requires :integration_id or :integration"
      end

    base_attrs =
      Map.drop(attrs, [:integration_id, "integration_id", :integration, "integration"])

    attrs =
      Enum.into(base_attrs, %{
        integration_id: integration_id,
        direction: :outbound,
        action: "pause_campaign",
        target: "campaign:gads-12345",
        payload_redacted: %{"event" => "incident_opened"},
        status: :success,
        duration_ms: 150,
        occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    IntegrationEventsContext.log_event!(attrs)
  end

  def integration_binding_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    integration_id =
      cond do
        id = attrs[:integration_id] -> id
        id = attrs["integration_id"] -> id
        ig = attrs[:integration] -> ig.id
        true -> raise ArgumentError, "binding fixture requires :integration_id or :integration"
      end

    monitor_id =
      cond do
        id = attrs[:monitor_id] -> id
        id = attrs["monitor_id"] -> id
        m = attrs[:monitor] -> m.id
        true -> raise ArgumentError, "binding fixture requires :monitor_id or :monitor"
      end

    base =
      Map.drop(attrs, [
        :integration_id,
        "integration_id",
        :integration,
        "integration",
        :monitor_id,
        "monitor_id",
        :monitor,
        "monitor"
      ])

    full =
      Enum.into(base, %{
        integration_id: integration_id,
        monitor_id: monitor_id,
        event_type: "incident_opened",
        action: "pause_campaign",
        target_id: "gads-#{System.unique_integer([:positive])}",
        target_label: nil
      })

    {:ok, binding} = IntegrationBindingsContext.create(full)
    binding
  end

  defp workspace_id_from_fixtures do
    workspace = Holter.MonitoringFixtures.workspace_fixture()
    workspace.id
  end
end
