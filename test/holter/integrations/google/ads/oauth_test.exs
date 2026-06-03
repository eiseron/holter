defmodule Holter.Integrations.Google.Ads.OAuthTest do
  use ExUnit.Case, async: true

  import Mox

  alias Holter.GoogleAdsApiFixtures
  alias Holter.Integrations.Google.Ads.OAuth

  setup :verify_on_exit!

  describe "authorization_url/1" do
    test "returns an ok tuple with a URL string" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert is_binary(url)
    end

    test "URL contains the state parameter" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert String.contains?(url, "state=state-abc")
    end

    test "URL targets the Google OAuth endpoint" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert String.starts_with?(url, "https://accounts.google.com/o/oauth2/v2/auth")
    end

    test "URL requests offline access" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert String.contains?(url, "access_type=offline")
    end

    test "URL includes the adwords scope" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert String.contains?(url, "adwords")
    end
  end

  describe "exchange_code/2" do
    test "returns the access_token from the token response" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "tok", "expires_in" => 3600}}}
      end)

      {:ok, credentials} = OAuth.exchange_code(%{"code" => "auth-code"}, "state-abc")

      assert credentials["access_token"] == "tok"
    end

    test "returns error tuple on non-200 response" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, GoogleAdsApiFixtures.unauthorized_response()}
      end)

      assert {:error, {:http_error, 401, _}} = OAuth.exchange_code(%{"code" => "bad-code"}, "s")
    end

    test "returns error tuple when code param is missing" do
      assert {:error, :missing_code} = OAuth.exchange_code(%{}, "state-abc")
    end

    test "propagates transport errors" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = OAuth.exchange_code(%{"code" => "code"}, "state")
    end
  end

  describe "refresh_token/1" do
    test "returns the new access_token on success" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "new-tok", "expires_in" => 3600}}}
      end)

      credentials = %{"access_token" => "old-tok", "refresh_token" => "ref-tok"}
      {:ok, new_creds} = OAuth.refresh_token(credentials)

      assert new_creds["access_token"] == "new-tok"
    end

    test "preserves the refresh_token from existing credentials" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "new-tok", "expires_in" => 3600}}}
      end)

      credentials = %{"access_token" => "old-tok", "refresh_token" => "ref-tok"}
      {:ok, new_creds} = OAuth.refresh_token(credentials)

      assert new_creds["refresh_token"] == "ref-tok"
    end

    test "returns :revoked on 401 response" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, GoogleAdsApiFixtures.unauthorized_response()}
      end)

      credentials = %{"access_token" => "tok", "refresh_token" => "ref"}

      assert {:error, :revoked} = OAuth.refresh_token(credentials)
    end

    test "returns http_error on unexpected status" do
      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, GoogleAdsApiFixtures.rate_limit_response()}
      end)

      credentials = %{"access_token" => "tok", "refresh_token" => "ref"}

      assert {:error, {:http_error, 429, _}} = OAuth.refresh_token(credentials)
    end
  end

  describe "revoke_token/1" do
    test "returns :ok on successful revocation" do
      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{}}}
      end)

      credentials = %{"access_token" => "tok"}

      assert :ok = OAuth.revoke_token(credentials)
    end

    test "returns error when revoke endpoint returns non-2xx status" do
      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 400, body: %{}}}
      end)

      credentials = %{"access_token" => "tok"}

      assert {:error, {:revoke_failed, 400}} = OAuth.revoke_token(credentials)
    end

    test "returns error when HTTP call fails" do
      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:error, :timeout}
      end)

      credentials = %{"access_token" => "tok"}

      assert {:error, {:revoke_failed, :timeout}} = OAuth.revoke_token(credentials)
    end
  end
end
