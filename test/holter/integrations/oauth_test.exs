defmodule Holter.Integrations.OAuthTest do
  use Holter.DataCase, async: false

  import Phoenix.ConnTest

  alias Holter.Integrations.OAuth

  setup do
    conn =
      build_conn()
      |> Plug.Conn.put_private(:phoenix_endpoint, HolterWeb.Endpoint)

    %{conn: conn}
  end

  describe "generate_state_token/2 and verify_state_token/2" do
    test "generates a verifiable state token", %{conn: conn} do
      ws = workspace_fixture()
      user_id = Ecto.UUID.generate()

      token =
        OAuth.generate_state_token(conn, %{
          workspace_id: ws.id,
          user_id: user_id,
          provider: :google_ads,
          name: "Google Ads — Main"
        })

      assert {:ok, claims} = OAuth.verify_state_token(conn, token)
      assert claims.workspace_id == ws.id
      assert claims.user_id == user_id
      assert claims.provider == "google_ads"
      assert claims.name == "Google Ads — Main"
    end

    test "returns {:error, :invalid} for a tampered token", %{conn: conn} do
      assert {:error, :invalid} = OAuth.verify_state_token(conn, "not.a.real.token")
    end

    test "returns {:error, :expired} for a token past its max_age", %{conn: conn} do
      ws = workspace_fixture()

      expired_token =
        Phoenix.Token.sign(
          HolterWeb.Endpoint,
          "integrations_oauth_state",
          %{workspace_id: ws.id, user_id: Ecto.UUID.generate(), provider: "google_ads"},
          signed_at: System.system_time(:second) - 400
        )

      assert {:error, :expired} = OAuth.verify_state_token(conn, expired_token)
    end
  end

  describe "exchange_and_persist/3" do
    test "creates an integration with status :active" do
      ws = workspace_fixture()
      credentials = %{"access_token" => "tok123"}

      assert {:ok, %{provider: :slack, status: :active, name: "Slack Main"}} =
               OAuth.exchange_and_persist(
                 ws.id,
                 %{provider: :slack, name: "Slack Main"},
                 credentials
               )
    end

    test "allows a second integration for the same provider when the name differs" do
      ws = workspace_fixture()

      OAuth.exchange_and_persist(ws.id, %{provider: :slack, name: "Slack Main"}, %{
        "access_token" => "tok1"
      })

      assert {:ok, %{name: "Slack Alt"}} =
               OAuth.exchange_and_persist(ws.id, %{provider: :slack, name: "Slack Alt"}, %{
                 "access_token" => "tok2"
               })
    end

    test "returns error when the same name already exists for the provider" do
      ws = workspace_fixture()

      OAuth.exchange_and_persist(ws.id, %{provider: :slack, name: "Slack Main"}, %{
        "access_token" => "tok1"
      })

      {:error, changeset} =
        OAuth.exchange_and_persist(ws.id, %{provider: :slack, name: "Slack Main"}, %{
          "access_token" => "tok2"
        })

      assert "an integration with this name already exists for this provider" in errors_on(
               changeset
             ).workspace_id
    end
  end

  describe "refresh_if_needed/2" do
    test "returns {:ok, integration} unchanged when token is valid" do
      ws = workspace_fixture()

      future =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :google_ads,
          credentials_encrypted: %{"access_token" => "tok", "expires_at" => future}
        )

      now = DateTime.utc_now()

      {:ok, returned} = OAuth.refresh_if_needed(integration, now)

      assert returned.id == integration.id
    end

    test "returns {:ok, integration} unchanged for unregistered provider when near expiry" do
      ws = workspace_fixture()

      near_expiry =
        DateTime.utc_now()
        |> DateTime.add(60, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :google_ads,
          credentials_encrypted: %{"access_token" => "tok", "expires_at" => near_expiry}
        )

      now = DateTime.utc_now()

      {:ok, returned} = OAuth.refresh_if_needed(integration, now)

      assert returned.id == integration.id
    end

    test "resets status to :active after successful credential refresh" do
      ws = workspace_fixture()

      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      past =
        DateTime.utc_now()
        |> DateTime.add(-10, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :slack,
          status: :reauth_required,
          credentials_encrypted: %{"access_token" => "old", "expires_at" => past}
        )

      new_creds = %{
        "access_token" => "refreshed",
        "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600))
      }

      expect(Holter.Integrations.ProviderMock, :refresh, fn _creds -> {:ok, new_creds} end)

      now = DateTime.utc_now()
      {:ok, updated} = OAuth.refresh_if_needed(integration, now)

      assert updated.status == :active
    end

    test "persists refreshed access_token from provider response" do
      ws = workspace_fixture()

      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      past =
        DateTime.utc_now()
        |> DateTime.add(-10, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :slack,
          credentials_encrypted: %{"access_token" => "old", "expires_at" => past}
        )

      new_creds = %{
        "access_token" => "refreshed",
        "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600))
      }

      expect(Holter.Integrations.ProviderMock, :refresh, fn _creds -> {:ok, new_creds} end)

      now = DateTime.utc_now()
      {:ok, updated} = OAuth.refresh_if_needed(integration, now)

      assert updated.credentials_encrypted["access_token"] == "refreshed"
    end

    test "marks integration as reauth_required when provider returns :revoked" do
      ws = workspace_fixture()

      Application.put_env(:holter, :integration_providers, %{
        slack: Holter.Integrations.ProviderMock
      })

      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      past =
        DateTime.utc_now()
        |> DateTime.add(-10, :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      integration =
        integration_fixture(
          workspace_id: ws.id,
          provider: :slack,
          credentials_encrypted: %{"access_token" => "old", "expires_at" => past}
        )

      expect(Holter.Integrations.ProviderMock, :refresh, fn _creds -> {:error, :revoked} end)

      now = DateTime.utc_now()

      assert {:error, :reauth_required} = OAuth.refresh_if_needed(integration, now)
    end
  end
end
