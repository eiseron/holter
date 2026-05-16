defmodule Holter.Integrations.Workers.IntegrationDispatcherTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  import Mox

  alias Holter.Integrations.Models.IntegrationEvent
  alias Holter.Integrations.ProviderMock
  alias Holter.Integrations.Workers.IntegrationDispatcher
  alias Holter.Repo

  setup :verify_on_exit!

  defp with_provider_mock(context) do
    Application.put_env(:holter, :integration_providers, %{google_ads: ProviderMock})
    on_exit(fn -> Application.delete_env(:holter, :integration_providers) end)
    context
  end

  describe "perform/1 — provider not registered" do
    test "discards job when provider has no implementation" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      assert {:discard, _reason} =
               perform_job(IntegrationDispatcher, %{
                 "integration_id" => integration.id,
                 "workspace_id" => ws.id,
                 "event" => "incident_opened",
                 "incident_id" => Ecto.UUID.generate()
               })
    end
  end

  describe "perform/1 — successful dispatch" do
    setup :with_provider_mock

    test "returns :ok when provider dispatch succeeds" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      incident_id = Ecto.UUID.generate()
      monitor_id = Ecto.UUID.generate()

      stub(ProviderMock, :dispatch, fn _integration, _event, _payload -> :ok end)

      assert :ok =
               perform_job(IntegrationDispatcher, %{
                 "integration_id" => integration.id,
                 "workspace_id" => ws.id,
                 "event" => "incident_opened",
                 "incident_id" => incident_id,
                 "monitor_id" => monitor_id
               })
    end

    test "logs a success IntegrationEvent after dispatch" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      incident_id = Ecto.UUID.generate()

      stub(ProviderMock, :dispatch, fn _integration, _event, _payload -> :ok end)

      perform_job(IntegrationDispatcher, %{
        "integration_id" => integration.id,
        "workspace_id" => ws.id,
        "event" => "incident_opened",
        "incident_id" => incident_id
      })

      assert Repo.exists?(
               from e in IntegrationEvent,
                 where: e.integration_id == ^integration.id and e.status == :success
             )
    end

    test "includes monitor_id in incident stub passed to dispatch" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      incident_id = Ecto.UUID.generate()
      monitor_id = Ecto.UUID.generate()

      expect(ProviderMock, :dispatch, fn _integration, _event, payload ->
        assert payload.monitor_id == monitor_id
        :ok
      end)

      perform_job(IntegrationDispatcher, %{
        "integration_id" => integration.id,
        "workspace_id" => ws.id,
        "event" => "incident_opened",
        "incident_id" => incident_id,
        "monitor_id" => monitor_id
      })
    end
  end

  describe "perform/1 — failed dispatch" do
    setup :with_provider_mock

    test "returns {:error, reason} when provider dispatch fails" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      incident_id = Ecto.UUID.generate()

      stub(ProviderMock, :dispatch, fn _integration, _event, _payload -> {:error, :timeout} end)

      assert {:error, :timeout} =
               perform_job(IntegrationDispatcher, %{
                 "integration_id" => integration.id,
                 "workspace_id" => ws.id,
                 "event" => "incident_opened",
                 "incident_id" => incident_id
               })
    end

    test "logs a failed IntegrationEvent when dispatch returns error" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      incident_id = Ecto.UUID.generate()

      stub(ProviderMock, :dispatch, fn _integration, _event, _payload -> {:error, :timeout} end)

      perform_job(IntegrationDispatcher, %{
        "integration_id" => integration.id,
        "workspace_id" => ws.id,
        "event" => "incident_opened",
        "incident_id" => incident_id
      })

      assert Repo.exists?(
               from e in IntegrationEvent,
                 where: e.integration_id == ^integration.id and e.status == :failed
             )
    end
  end
end
