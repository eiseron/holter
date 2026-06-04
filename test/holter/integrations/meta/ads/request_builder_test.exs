defmodule Holter.Integrations.Meta.Ads.RequestBuilderTest do
  use ExUnit.Case, async: false

  alias Holter.Integrations.Meta.Ads.RequestBuilder

  defp integration, do: %{credentials_encrypted: %{"access_token" => "tok-abc"}}

  describe "build/3 — object id guard" do
    test "accepts a numeric Graph object id" do
      assert {:ok, _} = RequestBuilder.build("23847239847", "PAUSED", integration())
    end

    test "rejects an id with path traversal characters" do
      assert {:error, :invalid_target_id} =
               RequestBuilder.build("../../me/adaccounts", "PAUSED", integration())
    end

    test "rejects a non-binary id" do
      assert {:error, :invalid_target_id} = RequestBuilder.build(nil, "PAUSED", integration())
    end
  end

  describe "build/3 — request shape" do
    test "targets the Graph object URL on the configured api version" do
      {:ok, request} = RequestBuilder.build("100000000000111", "PAUSED", integration())

      assert request.url == "https://graph.facebook.com/v25.0/100000000000111"
    end

    test "declares a form-urlencoded content type" do
      {:ok, request} = RequestBuilder.build("100000000000111", "PAUSED", integration())

      assert {"content-type", "application/x-www-form-urlencoded"} in request.headers
    end

    test "carries the given status into the body" do
      {:ok, request} = RequestBuilder.build("100000000000111", "ACTIVE", integration())

      assert request.body["status"] == "ACTIVE"
    end

    test "sends the access_token in the body" do
      {:ok, request} = RequestBuilder.build("100000000000111", "PAUSED", integration())

      assert request.body["access_token"] == "tok-abc"
    end
  end

  describe "build/3 — configurable api version" do
    setup do
      original = Application.get_env(:holter, :meta_ads, [])
      on_exit(fn -> Application.put_env(:holter, :meta_ads, original) end)
      :ok
    end

    test "uses the api version from config in the Graph URL" do
      config = Application.get_env(:holter, :meta_ads, [])
      Application.put_env(:holter, :meta_ads, Keyword.put(config, :api_version, "v24.0"))

      {:ok, request} = RequestBuilder.build("100000000000111", "PAUSED", integration())

      assert request.url == "https://graph.facebook.com/v24.0/100000000000111"
    end
  end
end
