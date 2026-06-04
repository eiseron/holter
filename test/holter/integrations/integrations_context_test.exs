defmodule Holter.Integrations.IntegrationsContextTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.IntegrationsContext
  alias Holter.Integrations.Models.Integration

  describe "create/1" do
    test "inserts an integration with required fields" do
      ws = workspace_fixture()

      assert {:ok,
              %Integration{
                provider: :google_ads,
                name: "Google Ads Main",
                status: :active
              }} =
               IntegrationsContext.create(%{
                 workspace_id: ws.id,
                 provider: :google_ads,
                 name: "Google Ads Main"
               })
    end

    test "returns error changeset when provider is missing" do
      ws = workspace_fixture()
      {:error, cs} = IntegrationsContext.create(%{workspace_id: ws.id})
      assert "can't be blank" in errors_on(cs).provider
    end

    test "called without attrs defaults to empty map" do
      {:error, cs} = IntegrationsContext.create()
      assert "can't be blank" in errors_on(cs).workspace_id
    end

    test "stores and retrieves encrypted credentials round-trip" do
      ws = workspace_fixture()
      credentials = %{"access_token" => "tok_abc", "refresh_token" => "ref_xyz"}

      {:ok, integration} =
        IntegrationsContext.create(%{
          workspace_id: ws.id,
          provider: :slack,
          name: "Slack",
          credentials_encrypted: credentials
        })

      loaded = IntegrationsContext.get!(integration.id)
      assert loaded.credentials_encrypted == credentials
    end
  end

  describe "get/1" do
    test "returns {:ok, integration} for an existing id" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      {:ok, %Integration{id: id}} = IntegrationsContext.get(integration.id)
      assert id == integration.id
    end

    test "returns {:error, :not_found} for a non-existent id" do
      assert {:error, :not_found} =
               IntegrationsContext.get(Ecto.UUID.generate())
    end

    test "returns {:error, :not_found} for an invalid uuid" do
      assert {:error, :not_found} = IntegrationsContext.get("not-a-uuid")
    end
  end

  describe "get_by_workspace_and_provider/2" do
    test "returns {:ok, integration} for a connected provider in the workspace" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      expected_id = integration.id

      assert {:ok, %Integration{id: ^expected_id, provider: :google_ads}} =
               IntegrationsContext.get_by_workspace_and_provider(ws.id, :google_ads)
    end

    test "returns {:error, :not_found} when the workspace has no such provider" do
      ws = workspace_fixture()
      _other = integration_fixture(workspace_id: ws.id, provider: :slack)

      assert {:error, :not_found} =
               IntegrationsContext.get_by_workspace_and_provider(ws.id, :google_ads)
    end

    test "does not cross workspace boundaries" do
      ws_a = workspace_fixture()
      ws_b = workspace_fixture()
      _integration_a = integration_fixture(workspace_id: ws_a.id, provider: :google_ads)

      assert {:error, :not_found} =
               IntegrationsContext.get_by_workspace_and_provider(ws_b.id, :google_ads)
    end
  end

  describe "list/1" do
    test "returns all integrations for the workspace" do
      ws = workspace_fixture()
      _google = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      _slack = integration_fixture(workspace_id: ws.id, provider: :slack)

      assert length(IntegrationsContext.list(ws.id)) == 2
    end

    test "returns integrations ordered by provider name" do
      ws = workspace_fixture()
      _google = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      _slack = integration_fixture(workspace_id: ws.id, provider: :slack)

      providers = IntegrationsContext.list(ws.id) |> Enum.map(& &1.provider)
      assert providers == Enum.sort(providers)
    end

    test "does not return integrations from other workspaces" do
      ws1 = workspace_fixture()
      ws2 = workspace_fixture()
      _ig = integration_fixture(workspace_id: ws1.id)

      assert IntegrationsContext.list(ws2.id) == []
    end
  end

  describe "update_status/2" do
    test "updates status and error metadata" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, updated} =
        IntegrationsContext.update_status(integration, %{
          status: :reauth_required,
          last_error_at: now,
          last_error_reason: "token_expired"
        })

      assert %{status: :reauth_required, last_error_reason: "token_expired"} = updated
    end
  end

  describe "get!/1" do
    test "returns the integration for an existing id" do
      ws = workspace_fixture()
      %Integration{id: id} = integration_fixture(workspace_id: ws.id)

      assert %Integration{id: ^id} = IntegrationsContext.get!(id)
    end

    test "raises Ecto.NoResultsError for a non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        IntegrationsContext.get!(Ecto.UUID.generate())
      end
    end
  end

  describe "update/2" do
    test "updates allowed fields and returns {:ok, integration}" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert {:ok, %Integration{settings: %{"key" => "value"}}} =
               IntegrationsContext.update(integration, %{settings: %{"key" => "value"}})
    end

    test "returns {:error, changeset} for invalid attrs" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert {:error, %Ecto.Changeset{}} =
               IntegrationsContext.update(integration, %{provider: :unknown_provider})
    end
  end

  describe "update_credentials/2" do
    test "encrypts and persists new credentials" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert {:ok, %Integration{credentials_encrypted: %{"access_token" => "new_token_xyz"}}} =
               IntegrationsContext.update_credentials(integration, %{
                 credentials_encrypted: %{"access_token" => "new_token_xyz"}
               })
    end
  end

  describe "change/2" do
    test "returns a changeset for the integration" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert %Ecto.Changeset{valid?: true} =
               IntegrationsContext.change(integration, %{settings: %{}})
    end

    test "called without attrs defaults to empty map" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      assert %Ecto.Changeset{} = IntegrationsContext.change(integration)
    end
  end

  describe "delete/1" do
    test "removes the integration and returns {:ok, integration}" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)

      {:ok, _} = IntegrationsContext.delete(integration)
      assert {:error, :not_found} = IntegrationsContext.get(integration.id)
    end
  end
end
