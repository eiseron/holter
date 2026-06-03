defmodule Holter.Integrations.Google.AdsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Holter.Integrations.Google.Ads

  setup :verify_on_exit!

  defp integration do
    %{
      settings: %{"customer_id" => "1234567890"},
      credentials_encrypted: %{"access_token" => "tok"}
    }
  end

  describe "display_name/0" do
    test "returns the human-readable provider name" do
      assert Ads.display_name() == "Google Ads"
    end
  end

  describe "supported_events/0" do
    test "includes incident_opened" do
      assert "incident_opened" in Ads.supported_events()
    end

    test "includes incident_resolved" do
      assert "incident_resolved" in Ads.supported_events()
    end
  end

  describe "supported_actions/0" do
    test "includes pause_campaign" do
      assert :pause_campaign in Ads.supported_actions()
    end

    test "includes resume_campaign" do
      assert :resume_campaign in Ads.supported_actions()
    end
  end

  describe "encode/3" do
    test "encodes pause_campaign into a PAUSED mutate request" do
      {:ok, request} = Ads.encode("pause_campaign", %{"id" => "c-1"}, integration())

      assert get_in(request.body, ["operations", Access.at(0), "update", "status"]) == "PAUSED"
    end

    test "encodes resume_campaign into an ENABLED mutate request" do
      {:ok, request} = Ads.encode("resume_campaign", %{"id" => "c-1"}, integration())

      assert get_in(request.body, ["operations", Access.at(0), "update", "status"]) == "ENABLED"
    end

    test "returns :unsupported for an action it does not handle" do
      assert :unsupported = Ads.encode("pause_ad_set", %{"id" => "x"}, %{})
    end
  end

  describe "oauth_url/2" do
    test "delegates to OAuth.authorization_url and returns an ok tuple" do
      {:ok, url} = Ads.oauth_url("ws-123", "state-abc")

      assert is_binary(url)
    end
  end

  describe "handle_callback/2" do
    test "returns ok credentials on successful code exchange" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "tok", "expires_in" => 3600}}}
      end)

      {:ok, credentials} = Ads.handle_callback(%{"code" => "auth-code"}, "state-abc")

      assert credentials["access_token"] == "tok"
    end

    test "returns error when code is missing" do
      assert {:error, :missing_code} = Ads.handle_callback(%{}, "state-abc")
    end
  end

  describe "refresh/1" do
    test "returns refreshed credentials on success" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "new-tok", "expires_in" => 3600}}}
      end)

      credentials = %{"access_token" => "old-tok", "refresh_token" => "ref-tok"}
      {:ok, new_creds} = Ads.refresh(credentials)

      assert new_creds["access_token"] == "new-tok"
    end
  end

  describe "revoke/1" do
    test "returns :ok on successful revocation" do
      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{}}}
      end)

      credentials = %{"access_token" => "tok"}

      assert :ok = Ads.revoke(credentials)
    end
  end
end
