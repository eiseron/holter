defmodule Holter.Integrations.Workers.IntegrationDispatcherTest do
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  import Mox

  alias Holter.Integrations.Models.IntegrationEvent
  alias Holter.Integrations.ProviderMock
  alias Holter.Integrations.Workers.IntegrationDispatcher
  alias Holter.Repo

  setup :verify_on_exit!

  setup do
    on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)
  end

  describe "perform/1" do
    test "discards job when provider has no implementation" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)

      result =
        perform_job(IntegrationDispatcher, %{
          "integration_id" => integration.id,
          "workspace_id" => ws.id,
          "event" => "incident_opened",
          "incident_id" => Ecto.UUID.generate()
        })

      assert {:discard, _reason} = result
    end

    test "snoozes job when integration is rate-limited" do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      Application.put_env(:holter, :integration_rate_limits, %{slack: {5_000, 0}})

      on_exit(fn ->
        Application.put_env(:holter, :integration_rate_limits, %{
          google_ads: {:timer.hours(24), 1_000_000},
          meta_ads: {:timer.hours(1), 1_000_000},
          slack: {:timer.minutes(1), 1_000_000}
        })
      end)

      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :slack)

      result =
        perform_job(IntegrationDispatcher, %{
          "integration_id" => integration.id,
          "workspace_id" => ws.id,
          "event" => "incident_opened",
          "incident_id" => Ecto.UUID.generate()
        })

      assert {:snooze, 60} = result
    end

    test "dispatches successfully when provider returns :ok" do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      stub(Holter.Integrations.ProviderMock, :refresh, fn creds -> {:ok, creds} end)

      expect(Holter.Integrations.ProviderMock, :dispatch, fn _integration, _event, _payload ->
        :ok
      end)

      ws = workspace_fixture()

      future =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :slack,
          credentials_encrypted: %{"access_token" => "tok", "expires_at" => future}
        )

      result =
        perform_job(IntegrationDispatcher, %{
          "integration_id" => integration.id,
          "workspace_id" => ws.id,
          "event" => "incident_opened",
          "incident_id" => Ecto.UUID.generate()
        })

      assert :ok = result
    end

    test "handles dispatch error by classifying and returning Oban control" do
      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      stub(Holter.Integrations.ProviderMock, :refresh, fn creds -> {:ok, creds} end)

      expect(Holter.Integrations.ProviderMock, :dispatch, fn _integration, _event, _payload ->
        {:error, :rate_limited}
      end)

      ws = workspace_fixture()

      future =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :slack,
          credentials_encrypted: %{"access_token" => "tok", "expires_at" => future}
        )

      result =
        perform_job(IntegrationDispatcher, %{
          "integration_id" => integration.id,
          "workspace_id" => ws.id,
          "event" => "incident_opened",
          "incident_id" => Ecto.UUID.generate()
        })

      assert {:snooze, 60} = result
    end

    test "logs a success IntegrationEvent after dispatch" do
      Application.put_env(:holter, :integration_providers, %{google_ads: ProviderMock})
      stub(ProviderMock, :refresh, fn creds -> {:ok, creds} end)
      stub(ProviderMock, :dispatch, fn _integration, _event, _payload -> :ok end)

      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      incident_id = Ecto.UUID.generate()

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
      Application.put_env(:holter, :integration_providers, %{google_ads: ProviderMock})
      stub(ProviderMock, :refresh, fn creds -> {:ok, creds} end)

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

    test "logs a failed IntegrationEvent when dispatch returns error" do
      Application.put_env(:holter, :integration_providers, %{google_ads: ProviderMock})
      stub(ProviderMock, :refresh, fn creds -> {:ok, creds} end)
      stub(ProviderMock, :dispatch, fn _integration, _event, _payload -> {:error, :timeout} end)

      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      incident_id = Ecto.UUID.generate()

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

    test "discards job when OAuth refresh returns unexpected error via catch-all else clause" do
      Application.put_env(:holter, :integration_providers, %{google_ads: ProviderMock})
      stub(ProviderMock, :refresh, fn _creds -> {:error, :network_error} end)

      ws = workspace_fixture()

      expired =
        DateTime.utc_now()
        |> DateTime.add(-3600, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :google_ads,
          credentials_encrypted: %{"access_token" => "tok", "expires_at" => expired}
        )

      result =
        perform_job(IntegrationDispatcher, %{
          "integration_id" => integration.id,
          "workspace_id" => ws.id,
          "event" => "incident_opened",
          "incident_id" => Ecto.UUID.generate()
        })

      assert {:discard, _reason} = result
    end

    test "logs a failed IntegrationEvent when OAuth refresh returns unexpected error" do
      Application.put_env(:holter, :integration_providers, %{google_ads: ProviderMock})
      stub(ProviderMock, :refresh, fn _creds -> {:error, :network_error} end)

      ws = workspace_fixture()

      expired =
        DateTime.utc_now()
        |> DateTime.add(-3600, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :google_ads,
          credentials_encrypted: %{"access_token" => "tok", "expires_at" => expired}
        )

      perform_job(IntegrationDispatcher, %{
        "integration_id" => integration.id,
        "workspace_id" => ws.id,
        "event" => "incident_opened",
        "incident_id" => Ecto.UUID.generate()
      })

      assert Repo.exists?(
               from e in IntegrationEvent,
                 where: e.integration_id == ^integration.id and e.status == :failed
             )
    end
  end
end
