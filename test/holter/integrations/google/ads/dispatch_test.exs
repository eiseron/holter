defmodule Holter.Integrations.Google.Ads.DispatchTest do
  use Holter.DataCase, async: false

  import Mox

  alias Holter.GoogleAdsApiFixtures
  alias Holter.Integrations.Engine.ActionRunner
  alias Holter.Integrations.Google.Ads

  setup :verify_on_exit!

  defp integration_with(overrides \\ %{}) do
    ws = workspace_fixture()

    base_attrs = %{
      workspace_id: ws.id,
      provider: :google_ads,
      credentials_encrypted: %{
        "access_token" => "test-access-token",
        "refresh_token" => "test-refresh-token",
        "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600))
      },
      settings: %{"customer_id" => "1234567890"}
    }

    attrs = Map.merge(base_attrs, overrides)
    integration_fixture(attrs)
  end

  defp targets(campaign_ids, action) do
    Enum.map(campaign_ids, fn id ->
      %{"type" => "campaign", "action" => action, "id" => id, "label" => nil}
    end)
  end

  defp payload_with(campaign_ids, action \\ "pause_campaign"),
    do: %{targets: targets(campaign_ids, action)}

  defp run(integration, payload), do: ActionRunner.run(Ads, integration, payload)

  describe "ActionRunner.run with Google.Ads — pause_campaign targets" do
    test "returns :ok when all campaign pause calls succeed" do
      integration = integration_with()

      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, GoogleAdsApiFixtures.success_response()}
      end)

      assert :ok = run(integration, payload_with(["camp-111", "camp-222"]))
    end

    test "targets the URL for the integration customer_id" do
      integration = integration_with()
      test_pid = self()

      stub(Holter.Integrations.HttpClientMock, :post, fn url, _body, _headers ->
        send(test_pid, {:captured_url, url})
        {:ok, GoogleAdsApiFixtures.success_response()}
      end)

      run(integration, payload_with(["camp-111"]))

      assert_received {:captured_url,
                       "https://googleads.googleapis.com/v17/customers/1234567890/campaigns:mutate"}
    end

    test "returns rate_limited error when API responds with 429" do
      integration = integration_with()

      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, GoogleAdsApiFixtures.rate_limit_response()}
      end)

      assert {:error, :rate_limited} = run(integration, payload_with(["c-1"]))
    end

    test "includes login-customer-id header when manager_customer_id is set" do
      integration =
        integration_with(%{
          settings: %{"customer_id" => "1234567890", "manager_customer_id" => "9876543210"}
        })

      test_pid = self()

      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, headers ->
        send(test_pid, {:captured_headers, headers})
        {:ok, GoogleAdsApiFixtures.success_response()}
      end)

      run(integration, payload_with(["c-1"]))

      assert_received {:captured_headers, [{"login-customer-id", "9876543210"} | _]}
    end

    test "makes no HTTP calls when payload has no campaign targets" do
      integration = integration_with()

      assert :ok = run(integration, %{targets: []})
    end

    test "returns {:http_error, status, body} and halts on a non-2xx/non-429 response" do
      integration = integration_with()

      expect(Holter.Integrations.HttpClientMock, :post, 1, fn _url, _body, _headers ->
        {:ok, %{status: 500, body: %{"error" => "boom"}}}
      end)

      assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
               run(integration, payload_with(["camp-111", "camp-222"]))
    end

    test "propagates a transport error and halts before the second target" do
      integration = integration_with()

      expect(Holter.Integrations.HttpClientMock, :post, 1, fn _url, _body, _headers ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = run(integration, payload_with(["camp-111", "camp-222"]))
    end

    test "rejects a malformed customer_id without making any HTTP call" do
      integration = integration_with(%{settings: %{"customer_id" => "../../etc/passwd"}})

      assert {:error, :invalid_customer_id} = run(integration, payload_with(["camp-111"]))
    end

    test "skips production-shaped targets whose action the runner does not recognise" do
      integration = integration_with()

      payload = %{
        targets: [
          %{"type" => "channel", "action" => "post_message", "id" => "ch-1", "label" => nil},
          %{"type" => "webhook", "action" => "send_event", "id" => "wh-1", "label" => nil}
        ]
      }

      assert :ok = run(integration, payload)
    end
  end

  describe "ActionRunner.run with Google.Ads — resume_campaign targets" do
    test "resumes campaigns provided in payload targets with resume_campaign action" do
      integration = integration_with()
      test_pid = self()

      expect(Holter.Integrations.HttpClientMock, :post, 1, fn _url, body, _headers ->
        decoded = Jason.decode!(body)
        resource_name = get_in(decoded, ["operations", Access.at(0), "update", "resourceName"])
        send(test_pid, {:resource_name, resource_name})
        {:ok, GoogleAdsApiFixtures.success_response()}
      end)

      run(integration, payload_with(["camp-111"], "resume_campaign"))

      assert_received {:resource_name, "customers/1234567890/campaigns/camp-111"}
    end

    test "returns :ok and makes no HTTP calls when no campaign targets are provided" do
      integration = integration_with()

      assert :ok = run(integration, %{targets: []})
    end

    test "resumes all campaign targets with resume_campaign action" do
      integration = integration_with()

      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, GoogleAdsApiFixtures.success_response()}
      end)

      assert :ok = run(integration, payload_with(["camp-111", "camp-222"], "resume_campaign"))
    end
  end
end
