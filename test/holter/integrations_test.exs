defmodule Holter.IntegrationsTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations
  alias Holter.Integrations.Models.Integration
  alias Holter.Integrations.Models.IntegrationEvent

  describe "integration_providers/0" do
    test "includes :google_ads" do
      assert :google_ads in Integrations.integration_providers()
    end

    test "includes :meta_ads" do
      assert :meta_ads in Integrations.integration_providers()
    end
  end

  describe "integration_statuses/0" do
    test "includes :active" do
      assert :active in Integrations.integration_statuses()
    end

    test "includes :reauth_required" do
      assert :reauth_required in Integrations.integration_statuses()
    end
  end

  describe "integration_event_directions/0" do
    test "includes :outbound" do
      assert :outbound in Integrations.integration_event_directions()
    end

    test "includes :inbound" do
      assert :inbound in Integrations.integration_event_directions()
    end
  end

  describe "integration_event_statuses/0" do
    test "includes :success" do
      assert :success in Integrations.integration_event_statuses()
    end

    test "includes :failed" do
      assert :failed in Integrations.integration_event_statuses()
    end
  end

  describe "create_integration/1" do
    test "creates an integration and returns {:ok, integration}" do
      ws = workspace_fixture()

      assert {:ok, %Integration{provider: :slack}} =
               Integrations.create_integration(%{workspace_id: ws.id, provider: :slack})
    end
  end

  describe "get_integration/1" do
    test "returns {:ok, integration} for an existing id" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert {:ok, %Integration{}} = Integrations.get_integration(integration.id)
    end

    test "returns {:error, :not_found} for unknown id" do
      assert {:error, :not_found} = Integrations.get_integration(Ecto.UUID.generate())
    end
  end

  describe "get_integration!/1" do
    test "returns the integration struct" do
      ws = workspace_fixture()
      %Integration{id: id} = integration_fixture(workspace_id: ws.id)

      assert %Integration{id: ^id} = Integrations.get_integration!(id)
    end
  end

  describe "list_integrations/1" do
    test "returns all integrations for the workspace" do
      ws = workspace_fixture()
      _google = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      _slack = integration_fixture(workspace_id: ws.id, provider: :slack)

      assert length(Integrations.list_integrations(ws.id)) == 2
    end
  end

  describe "list_active_integrations_for_event/2" do
    test "returns active integrations subscribed to the event" do
      ws = workspace_fixture()
      _ig = integration_fixture(workspace_id: ws.id, subscribed_events: ["incident_opened"])

      results = Integrations.list_active_integrations_for_event(ws.id, "incident_opened")
      assert length(results) == 1
    end
  end

  describe "update_integration/2" do
    test "updates integration fields and returns {:ok, integration}" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert {:ok, %Integration{settings: %{"k" => "v"}}} =
               Integrations.update_integration(integration, %{settings: %{"k" => "v"}})
    end
  end

  describe "update_integration_status/2" do
    test "updates the status and returns {:ok, integration}" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, %Integration{status: :reauth_required}} =
               Integrations.update_integration_status(integration, %{
                 status: :reauth_required,
                 last_error_at: now,
                 last_error_reason: "token_expired"
               })
    end
  end

  describe "update_integration_credentials/2" do
    test "updates credentials and returns {:ok, integration}" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert {:ok, %Integration{credentials_encrypted: %{"access_token" => "tok"}}} =
               Integrations.update_integration_credentials(integration, %{
                 credentials_encrypted: %{"access_token" => "tok"}
               })
    end
  end

  describe "delete_integration/1" do
    test "returns {:ok, integration} on deletion" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert {:ok, %Integration{}} = Integrations.delete_integration(integration)
    end

    test "deleted integration is no longer found" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      Integrations.delete_integration(integration)

      assert {:error, :not_found} = Integrations.get_integration(integration.id)
    end
  end

  describe "change_integration/2" do
    test "returns a valid changeset for the integration" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert %Ecto.Changeset{valid?: true} =
               Integrations.change_integration(integration, %{settings: %{}})
    end

    test "called without attrs uses default empty map" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert %Ecto.Changeset{} = Integrations.change_integration(integration)
    end
  end

  describe "log_integration_event/1" do
    test "persists an integration event" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert %IntegrationEvent{action: "pause_campaign"} =
               Integrations.log_integration_event(%{
                 integration_id: integration.id,
                 direction: :outbound,
                 action: "pause_campaign",
                 status: :success,
                 occurred_at: now
               })
    end
  end

  describe "list_integration_events/2" do
    test "returns events for the integration" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      _event = integration_event_fixture(integration_id: integration.id)

      assert [%IntegrationEvent{}] = Integrations.list_integration_events(integration.id)
    end
  end

  describe "integration_fixture/1 cond branches" do
    test "creates integration without explicit workspace_id" do
      assert %Integration{} = integration_fixture()
    end

    test "accepts workspace struct as :workspace key" do
      %{id: ws_id} = workspace_fixture()

      assert %Integration{workspace_id: ^ws_id} =
               integration_fixture(workspace: %{id: ws_id})
    end

    test "accepts string workspace_id key" do
      %{id: ws_id} = workspace_fixture()

      assert %Integration{workspace_id: ^ws_id} =
               integration_fixture(%{"workspace_id" => ws_id})
    end
  end

  describe "integration_event_fixture/1 cond branches" do
    test "accepts integration struct as :integration key" do
      integration = integration_fixture()

      assert %IntegrationEvent{} = integration_event_fixture(integration: integration)
    end

    test "accepts string integration_id key" do
      %{id: ig_id} = integration_fixture()

      assert %IntegrationEvent{integration_id: ^ig_id} =
               integration_event_fixture(%{"integration_id" => ig_id})
    end

    test "raises when neither integration_id nor integration is given" do
      assert_raise ArgumentError, fn -> integration_event_fixture() end
    end
  end
end
