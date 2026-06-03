defmodule Holter.Integrations.Google.Ads.RequestBuilderTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Google.Ads.RequestBuilder

  defp integration(settings),
    do: %{settings: settings, credentials_encrypted: %{"access_token" => "tok"}}

  describe "build/3 — customer_id guard" do
    test "accepts a bare 10-digit customer id" do
      assert {:ok, _} =
               RequestBuilder.build(
                 "c-1",
                 "PAUSED",
                 integration(%{"customer_id" => "1234567890"})
               )
    end

    test "strips dashes from a formatted customer id" do
      {:ok, request} =
        RequestBuilder.build("c-1", "PAUSED", integration(%{"customer_id" => "123-456-7890"}))

      assert request.url =~ "/1234567890/"
    end

    test "rejects a customer id with path traversal characters" do
      assert {:error, :invalid_customer_id} =
               RequestBuilder.build(
                 "c-1",
                 "PAUSED",
                 integration(%{"customer_id" => "../../etc/passwd"})
               )
    end

    test "rejects a customer id with the wrong number of digits" do
      assert {:error, :invalid_customer_id} =
               RequestBuilder.build("c-1", "PAUSED", integration(%{"customer_id" => "12345"}))
    end
  end

  describe "build/3 — request shape" do
    test "targets the campaign mutate URL for the customer id" do
      {:ok, request} =
        RequestBuilder.build("camp-1", "PAUSED", integration(%{"customer_id" => "1234567890"}))

      assert request.url ==
               "https://googleads.googleapis.com/v17/customers/1234567890/campaigns:mutate"
    end

    test "carries the given status into the mutate body" do
      {:ok, request} =
        RequestBuilder.build("camp-1", "ENABLED", integration(%{"customer_id" => "1234567890"}))

      assert get_in(request.body, ["operations", Access.at(0), "update", "status"]) == "ENABLED"
    end

    test "includes login-customer-id header when manager_customer_id is set" do
      {:ok, request} =
        RequestBuilder.build(
          "camp-1",
          "PAUSED",
          integration(%{"customer_id" => "1234567890", "manager_customer_id" => "9876543210"})
        )

      assert {"login-customer-id", "9876543210"} in request.headers
    end
  end
end
