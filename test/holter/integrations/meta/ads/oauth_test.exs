defmodule Holter.Integrations.Meta.Ads.OAuthTest do
  use ExUnit.Case, async: true

  import Mox

  alias Holter.Integrations.Meta.Ads.OAuth
  alias Holter.MetaAdsApiFixtures

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

    test "URL targets the Meta OAuth endpoint" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert String.starts_with?(url, "https://www.facebook.com/v21.0/dialog/oauth")
    end

    test "URL includes ads_management scope" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert String.contains?(url, "ads_management")
    end

    test "URL includes ads_read scope" do
      {:ok, url} = OAuth.authorization_url("state-abc")

      assert String.contains?(url, "ads_read")
    end
  end

  describe "exchange_code/2" do
    test "returns the access_token from the long-lived token response" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "short-tok"}}}
      end)

      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "long-tok"}}}
      end)

      {:ok, credentials} = OAuth.exchange_code(%{"code" => "auth-code"}, "state-abc")

      assert credentials["access_token"] == "long-tok"
    end

    test "sets expires_at to approximately 60 days from now" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "short-tok"}}}
      end)

      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "long-tok", "expires_in" => 5_184_000}}}
      end)

      {:ok, credentials} = OAuth.exchange_code(%{"code" => "auth-code"}, "state-abc")

      {:ok, expires_at, _} = DateTime.from_iso8601(credentials["expires_at"])
      sixty_days_seconds = 60 * 24 * 3600
      diff = DateTime.diff(expires_at, DateTime.utc_now(), :second)

      assert diff > sixty_days_seconds - 10
    end

    test "returns error tuple when short-lived exchange fails" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, MetaAdsApiFixtures.unauthorized_response()}
      end)

      assert {:error, {:http_error, 401, _}} = OAuth.exchange_code(%{"code" => "bad-code"}, "s")
    end

    test "returns error tuple when long-lived exchange fails" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "short-tok"}}}
      end)

      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, MetaAdsApiFixtures.unauthorized_response()}
      end)

      assert {:error, {:http_error, 401, _}} = OAuth.exchange_code(%{"code" => "auth-code"}, "s")
    end

    test "returns error tuple when code param is missing" do
      assert {:error, :missing_code} = OAuth.exchange_code(%{}, "state-abc")
    end

    test "propagates transport errors on short-lived exchange" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = OAuth.exchange_code(%{"code" => "code"}, "state")
    end
  end

  describe "refresh_token/1" do
    test "returns the new access_token on success" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, %{status: 200, body: %{"access_token" => "new-tok", "expires_in" => 5_184_000}}}
      end)

      credentials = %{"access_token" => "old-tok"}
      {:ok, new_creds} = OAuth.refresh_token(credentials)

      assert new_creds["access_token"] == "new-tok"
    end

    test "returns :revoked on 401 response" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, MetaAdsApiFixtures.unauthorized_response()}
      end)

      credentials = %{"access_token" => "tok"}

      assert {:error, :revoked} = OAuth.refresh_token(credentials)
    end

    test "returns http_error on unexpected status" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:ok, MetaAdsApiFixtures.rate_limit_response()}
      end)

      credentials = %{"access_token" => "tok"}

      assert {:error, {:http_error, 429, _}} = OAuth.refresh_token(credentials)
    end

    test "propagates transport errors" do
      expect(Holter.Integrations.HttpClientMock, :get, fn _url, _headers ->
        {:error, :timeout}
      end)

      credentials = %{"access_token" => "tok"}

      assert {:error, :timeout} = OAuth.refresh_token(credentials)
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
