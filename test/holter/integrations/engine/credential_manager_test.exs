defmodule Holter.Integrations.Engine.CredentialManagerTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Engine.CredentialManager

  describe "classify_token_status/2" do
    test "returns :valid when token expires far in the future" do
      now = ~U[2026-01-01 12:00:00Z]
      credentials = %{"expires_at" => "2026-01-01T13:00:00Z"}

      assert :valid = CredentialManager.classify_token_status(credentials, now)
    end

    test "returns :near_expiry when token expires within 5 minutes" do
      now = ~U[2026-01-01 12:00:00Z]
      credentials = %{"expires_at" => "2026-01-01T12:04:00Z"}

      assert :near_expiry = CredentialManager.classify_token_status(credentials, now)
    end

    test "returns :expired when token expiry is in the past" do
      now = ~U[2026-01-01 12:00:00Z]
      credentials = %{"expires_at" => "2026-01-01T11:59:59Z"}

      assert :expired = CredentialManager.classify_token_status(credentials, now)
    end

    test "returns :expired when credentials have no expires_at" do
      now = ~U[2026-01-01 12:00:00Z]

      assert :expired = CredentialManager.classify_token_status(%{}, now)
    end

    test "returns :expired when expires_at is not a valid ISO datetime" do
      now = ~U[2026-01-01 12:00:00Z]
      credentials = %{"expires_at" => "not-a-date"}

      assert :expired = CredentialManager.classify_token_status(credentials, now)
    end
  end

  describe "build_refreshed_credentials/3" do
    test "replaces access_token from refresh response" do
      now = ~U[2026-01-01 12:00:00Z]

      existing = %{
        "access_token" => "old_token",
        "refresh_token" => "rt",
        "expires_at" => "2026-01-01T11:00:00Z"
      }

      response = %{"access_token" => "new_token", "expires_in" => 3600}

      result = CredentialManager.build_refreshed_credentials(existing, response, now)

      assert result["access_token"] == "new_token"
    end

    test "computes new expires_at from expires_in" do
      now = ~U[2026-01-01 12:00:00Z]
      existing = %{"access_token" => "old", "refresh_token" => "rt"}
      response = %{"access_token" => "new", "expires_in" => 3600}

      result = CredentialManager.build_refreshed_credentials(existing, response, now)

      assert result["expires_at"] == "2026-01-01T13:00:00Z"
    end

    test "removes expires_in from result" do
      now = ~U[2026-01-01 12:00:00Z]
      existing = %{"access_token" => "old"}
      response = %{"access_token" => "new", "expires_in" => 3600}

      result = CredentialManager.build_refreshed_credentials(existing, response, now)

      refute Map.has_key?(result, "expires_in")
    end

    test "preserves existing expires_at when response has no expires_in" do
      now = ~U[2026-01-01 12:00:00Z]
      existing = %{"access_token" => "old", "expires_at" => "2026-01-01T13:00:00Z"}
      response = %{"access_token" => "new"}

      result = CredentialManager.build_refreshed_credentials(existing, response, now)

      assert result["expires_at"] == "2026-01-01T13:00:00Z"
    end

    test "preserves refresh_token from existing credentials" do
      now = ~U[2026-01-01 12:00:00Z]
      existing = %{"access_token" => "old", "refresh_token" => "keep_me"}
      response = %{"access_token" => "new", "expires_in" => 3600}

      result = CredentialManager.build_refreshed_credentials(existing, response, now)

      assert result["refresh_token"] == "keep_me"
    end
  end

  describe "build_connect_attrs/3" do
    test "returns a map with workspace_id, provider, status and credentials" do
      credentials = %{"access_token" => "tok"}

      result = CredentialManager.build_connect_attrs("ws-1", :google_ads, credentials)

      assert %{
               workspace_id: "ws-1",
               provider: :google_ads,
               status: :active,
               credentials_encrypted: %{"access_token" => "tok"}
             } = result
    end
  end
end
