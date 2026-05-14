defmodule Holter.Integrations.Models.IntegrationTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.IntegrationsContext
  alias Holter.Integrations.Models.Integration

  describe "changeset/2" do
    test "accepts valid attributes" do
      ws = workspace_fixture()

      attrs = %{
        workspace_id: ws.id,
        provider: :google_ads,
        subscribed_events: ["incident_opened"]
      }

      changeset = Integration.changeset(%Integration{}, attrs)
      assert changeset.valid?
    end

    test "requires workspace_id" do
      cs = Integration.changeset(%Integration{}, %{provider: :slack})
      assert "can't be blank" in errors_on(cs).workspace_id
    end

    test "requires provider" do
      ws = workspace_fixture()
      cs = Integration.changeset(%Integration{}, %{workspace_id: ws.id})
      assert "can't be blank" in errors_on(cs).provider
    end

    test "rejects an unknown provider" do
      ws = workspace_fixture()

      cs =
        Integration.changeset(%Integration{}, %{
          workspace_id: ws.id,
          provider: :unknown_provider
        })

      assert "is invalid" in errors_on(cs).provider
    end

    test "rejects settings above 4096 bytes" do
      ws = workspace_fixture()
      big_value = String.duplicate("x", 4100)

      cs =
        Integration.changeset(%Integration{}, %{
          workspace_id: ws.id,
          provider: :slack,
          settings: %{"key" => big_value}
        })

      assert "must be at most 4096 bytes when encoded" in errors_on(cs).settings
    end

    test "rejects settings that cannot be JSON-serialized" do
      ws = workspace_fixture()

      cs =
        Integration.changeset(%Integration{}, %{
          workspace_id: ws.id,
          provider: :slack,
          settings: %{"key" => {1, 2, 3}}
        })

      assert "must be a JSON-serializable map" in errors_on(cs).settings
    end

    test "enforces unique (workspace_id, provider) constraint" do
      ws = workspace_fixture()

      {:ok, _} =
        IntegrationsContext.create(%{
          workspace_id: ws.id,
          provider: :google_ads
        })

      {:error, cs} =
        IntegrationsContext.create(%{
          workspace_id: ws.id,
          provider: :google_ads
        })

      assert "provider already connected for this workspace" in errors_on(cs).workspace_id
    end

    test "allows same provider in different workspaces" do
      ws1 = workspace_fixture()
      ws2 = workspace_fixture()

      {:ok, _} =
        IntegrationsContext.create(%{
          workspace_id: ws1.id,
          provider: :google_ads
        })

      assert {:ok, _} =
               IntegrationsContext.create(%{
                 workspace_id: ws2.id,
                 provider: :google_ads
               })
    end
  end

  describe "status_changeset/2" do
    test "changeset is valid for a valid status update" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        Integration.status_changeset(integration, %{
          status: :reauth_required,
          last_error_at: now,
          last_error_reason: "token_expired"
        })

      assert cs.valid?
    end

    test "applies the status change in the changeset" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        Integration.status_changeset(integration, %{
          status: :reauth_required,
          last_error_at: now,
          last_error_reason: "token_expired"
        })

      assert Ecto.Changeset.get_change(cs, :status) == :reauth_required
    end

    test "rejects an invalid status value" do
      integration = integration_fixture(workspace_id: workspace_fixture().id)
      cs = Integration.status_changeset(integration, %{status: :nonexistent_status})
      assert "is invalid" in errors_on(cs).status
    end
  end

  describe "credentials_changeset/2" do
    test "accepts valid encrypted credentials" do
      integration = integration_fixture(workspace_id: workspace_fixture().id)

      assert Integration.credentials_changeset(integration, %{
               credentials_encrypted: %{"token" => "abc"}
             }).valid?
    end
  end

  describe "providers/0" do
    test "includes :google_ads" do
      assert :google_ads in Integration.providers()
    end

    test "includes :meta_ads" do
      assert :meta_ads in Integration.providers()
    end
  end

  describe "statuses/0" do
    test "includes :active" do
      assert :active in Integration.statuses()
    end

    test "includes :reauth_required" do
      assert :reauth_required in Integration.statuses()
    end
  end
end
