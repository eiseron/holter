defmodule Holter.Integrations.IntegrationBindingsContextTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.IntegrationBindingsContext
  alias Holter.Integrations.Models.IntegrationBinding

  describe "create/1" do
    test "inserts a binding with valid attrs" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      {:ok, binding} =
        IntegrationBindingsContext.create(%{
          integration_id: integration.id,
          monitor_id: monitor.id,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-9000"
        })

      assert %IntegrationBinding{target_id: "gads-9000"} = binding
    end

    test "rejects unknown event_type" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      {:error, changeset} =
        IntegrationBindingsContext.create(%{
          integration_id: integration.id,
          monitor_id: monitor.id,
          event_type: "incident_unknown",
          action: "pause_campaign",
          target_id: "gads-1"
        })

      assert %{event_type: ["is invalid"]} = errors_on(changeset)
    end

    test "rejects unknown action" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      {:error, changeset} =
        IntegrationBindingsContext.create(%{
          integration_id: integration.id,
          monitor_id: monitor.id,
          event_type: "incident_opened",
          action: "unknown_kind",
          target_id: "x"
        })

      assert %{action: ["is invalid"]} = errors_on(changeset)
    end

    test "rejects duplicate (integration, monitor, event, action, target_id) combo" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      attrs = %{
        integration_id: integration.id,
        monitor_id: monitor.id,
        event_type: "incident_opened",
        action: "pause_campaign",
        target_id: "gads-dup"
      }

      {:ok, _} = IntegrationBindingsContext.create(attrs)
      {:error, changeset} = IntegrationBindingsContext.create(attrs)

      assert errors_on(changeset)
             |> Map.values()
             |> List.flatten()
             |> Enum.any?(&String.contains?(&1, "already exists"))
    end
  end

  describe "list_for_integration/1" do
    test "returns bindings only for the given integration" do
      ws = workspace_fixture()
      ig1 = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      ig2 = integration_fixture(workspace_id: ws.id, provider: :meta_ads)
      monitor = monitor_fixture(workspace_id: ws.id)

      _b1 =
        integration_binding_fixture(
          integration: ig1,
          monitor: monitor,
          target_id: "gads-1"
        )

      _b2 =
        integration_binding_fixture(
          integration: ig2,
          monitor: monitor,
          target_id: "meta-1"
        )

      bindings = IntegrationBindingsContext.list_for_integration(ig1.id)

      assert Enum.map(bindings, & &1.target_id) == ["gads-1"]
    end
  end

  describe "list_active_for_monitor_event/2" do
    test "returns bindings for the matching monitor + event" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)

      _matching =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          target_id: "gads-match"
        )

      _other_event =
        integration_binding_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_resolved",
          target_id: "gads-other"
        )

      bindings =
        IntegrationBindingsContext.list_active_for_monitor_event(monitor.id, "incident_opened")

      assert Enum.map(bindings, & &1.target_id) == ["gads-match"]
    end
  end

  describe "delete/1" do
    test "removes the binding from the database" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)
      binding = integration_binding_fixture(integration: integration, monitor: monitor)

      {:ok, _} = IntegrationBindingsContext.delete(binding)

      assert IntegrationBindingsContext.list_for_integration(integration.id) == []
    end
  end

  describe "get/1" do
    test "returns the binding when the id is valid" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      monitor = monitor_fixture(workspace_id: ws.id)
      binding = integration_binding_fixture(integration: integration, monitor: monitor)
      binding_id = binding.id

      assert {:ok, %{id: ^binding_id}} = IntegrationBindingsContext.get(binding.id)
    end

    test "returns :not_found when the id is unknown" do
      assert {:error, :not_found} = IntegrationBindingsContext.get(Ecto.UUID.generate())
    end

    test "returns :not_found for a non-UUID string" do
      assert {:error, :not_found} = IntegrationBindingsContext.get("not-a-uuid")
    end
  end

  describe "get!/1" do
    test "raises when the binding does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        IntegrationBindingsContext.get!(Ecto.UUID.generate())
      end
    end
  end

  describe "group_by_integration/1" do
    setup do
      ws = workspace_fixture()
      ig1 = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      ig2 = integration_fixture(workspace_id: ws.id, provider: :meta_ads)
      monitor = monitor_fixture(workspace_id: ws.id)

      b1 = integration_binding_fixture(integration: ig1, monitor: monitor, target_id: "g-1")
      b2 = integration_binding_fixture(integration: ig1, monitor: monitor, target_id: "g-2")
      b3 = integration_binding_fixture(integration: ig2, monitor: monitor, target_id: "m-1")

      grouped = IntegrationBindingsContext.group_by_integration([b1, b2, b3])
      %{grouped: grouped, ig1: ig1, ig2: ig2}
    end

    test "groups multiple bindings of the same integration together", %{
      grouped: grouped,
      ig1: ig1
    } do
      assert length(grouped[ig1.id]) == 2
    end

    test "keeps a separate group for each distinct integration", %{grouped: grouped, ig2: ig2} do
      assert length(grouped[ig2.id]) == 1
    end
  end
end
