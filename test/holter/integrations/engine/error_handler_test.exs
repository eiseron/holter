defmodule Holter.Integrations.Engine.ErrorHandlerTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.Engine.ErrorHandler
  alias Holter.Integrations.Models.Integration

  describe "handle/3" do
    test "returns {:snooze, 60} for a rate-limited error" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      now = DateTime.utc_now()

      result = ErrorHandler.handle(integration, :rate_limited, %{now: now, duration_ms: 0})

      assert {:snooze, 60} = result
    end

    test "returns {:discard, _} for a revoked token error" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      now = DateTime.utc_now()

      result = ErrorHandler.handle(integration, :revoked, %{now: now, duration_ms: 0})

      assert {:discard, _} = result
    end

    test "returns {:snooze, 300} for a provider_down error" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      now = DateTime.utc_now()

      result = ErrorHandler.handle(integration, :provider_down, %{now: now, duration_ms: 0})

      assert {:snooze, 300} = result
    end

    test "updates integration status to :rate_limited for rate_limited error" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      now = DateTime.utc_now()

      ErrorHandler.handle(integration, :rate_limited, %{now: now, duration_ms: 0})

      %Integration{status: status} = Holter.Integrations.get_integration!(integration.id)

      assert status == :rate_limited
    end

    test "updates integration status to :reauth_required for revoked error" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      now = DateTime.utc_now()

      ErrorHandler.handle(integration, :revoked, %{now: now, duration_ms: 0})

      %Integration{status: status} = Holter.Integrations.get_integration!(integration.id)

      assert status == :reauth_required
    end

    test "does not change status for token_expired error" do
      ws = workspace_fixture()

      integration =
        integration_fixture(workspace_id: ws.id, provider: :google_ads, status: :active)

      now = DateTime.utc_now()

      ErrorHandler.handle(integration, {:status, 401, %{}}, %{now: now, duration_ms: 0})

      %Integration{status: status} = Holter.Integrations.get_integration!(integration.id)

      assert status == :active
    end

    test "logs a dispatch_error IntegrationEvent with the provided duration_ms" do
      ws = workspace_fixture()
      integration = integration_fixture(workspace_id: ws.id, provider: :google_ads)
      now = DateTime.utc_now()

      ErrorHandler.handle(integration, :rate_limited, %{now: now, duration_ms: 123})

      events = Holter.Integrations.list_integration_events(integration.id)

      assert [%{action: "dispatch_error", status: :failed, duration_ms: 123}] = events
    end
  end
end
