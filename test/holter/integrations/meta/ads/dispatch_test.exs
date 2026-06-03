defmodule Holter.Integrations.Meta.Ads.DispatchTest do
  use Holter.DataCase, async: false

  import Mox

  alias Holter.Integrations.Engine.ActionRunner
  alias Holter.Integrations.Meta.Ads
  alias Holter.MetaAdsApiFixtures

  setup :verify_on_exit!

  defp integration_with(overrides \\ %{}) do
    ws = workspace_fixture()

    base_attrs = %{
      workspace_id: ws.id,
      provider: :meta_ads,
      credentials_encrypted: %{
        "access_token" => "test-access-token",
        "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 5_184_000))
      },
      settings: %{}
    }

    attrs = Map.merge(base_attrs, overrides)
    integration_fixture(attrs)
  end

  defp campaign_targets(ids, action) do
    Enum.map(ids, fn id ->
      %{"type" => "campaign", "action" => action, "id" => id, "label" => nil}
    end)
  end

  defp ad_set_targets(ids, action) do
    Enum.map(ids, fn id ->
      %{"type" => "ad_set", "action" => action, "id" => id, "label" => nil}
    end)
  end

  defp payload(opts) do
    campaigns = Keyword.get(opts, :campaigns, [])
    ad_sets = Keyword.get(opts, :ad_sets, [])
    campaign_action = Keyword.get(opts, :campaign_action, "pause_campaign")
    ad_set_action = Keyword.get(opts, :ad_set_action, "pause_ad_set")

    %{
      targets:
        campaign_targets(campaigns, campaign_action) ++ ad_set_targets(ad_sets, ad_set_action)
    }
  end

  defp run(integration, payload), do: ActionRunner.run(Ads, integration, payload)

  describe "ActionRunner.run with Meta.Ads — pause targets" do
    test "returns :ok when all campaign and ad set pause calls succeed" do
      integration = integration_with()

      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, MetaAdsApiFixtures.success_response()}
      end)

      assert :ok =
               run(
                 integration,
                 payload(
                   campaigns: ["100000000000111", "100000000000222"],
                   ad_sets: ["100000000000333"]
                 )
               )
    end

    test "targets the campaign URL for each campaign target" do
      integration = integration_with()
      test_pid = self()

      stub(Holter.Integrations.HttpClientMock, :post, fn url, _body, _headers ->
        send(test_pid, {:captured_url, url})
        {:ok, MetaAdsApiFixtures.success_response()}
      end)

      run(integration, payload(campaigns: ["100000000000111"]))

      assert_received {:captured_url, "https://graph.facebook.com/v21.0/100000000000111"}
    end

    test "targets the ad set URL for each ad_set target" do
      integration = integration_with()
      test_pid = self()

      stub(Holter.Integrations.HttpClientMock, :post, fn url, _body, _headers ->
        send(test_pid, {:captured_url, url})
        {:ok, MetaAdsApiFixtures.success_response()}
      end)

      run(integration, payload(ad_sets: ["100000000000333"]))

      assert_received {:captured_url, "https://graph.facebook.com/v21.0/100000000000333"}
    end

    test "returns rate_limited error when API responds with 429 on campaign" do
      integration = integration_with()

      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, MetaAdsApiFixtures.rate_limit_response()}
      end)

      assert {:error, :rate_limited} = run(integration, payload(campaigns: ["100000000000001"]))
    end

    test "sends access_token in the request body" do
      integration =
        integration_with(%{
          credentials_encrypted: %{
            "access_token" => "my-access-token",
            "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 5_184_000))
          }
        })

      test_pid = self()

      stub(Holter.Integrations.HttpClientMock, :post, fn _url, body, _headers ->
        decoded = Jason.decode!(body)
        send(test_pid, {:access_token, decoded["access_token"]})
        {:ok, MetaAdsApiFixtures.success_response()}
      end)

      run(integration, payload(campaigns: ["100000000000111"]))

      assert_received {:access_token, "my-access-token"}
    end

    test "rejects a non-numeric target id without making any HTTP call" do
      integration = integration_with()

      assert {:error, :invalid_target_id} =
               run(integration, payload(campaigns: ["../../me/adaccounts"]))
    end
  end

  describe "ActionRunner.run with Meta.Ads — resume targets" do
    test "resumes campaigns from payload targets" do
      integration = integration_with()
      test_pid = self()

      expect(Holter.Integrations.HttpClientMock, :post, 1, fn url, _body, _headers ->
        send(test_pid, {:captured_url, url})
        {:ok, MetaAdsApiFixtures.success_response()}
      end)

      run(
        integration,
        payload(campaigns: ["100000000000111"], campaign_action: "resume_campaign")
      )

      assert_received {:captured_url, "https://graph.facebook.com/v21.0/100000000000111"}
    end

    test "resumes ad sets from payload targets" do
      integration = integration_with()
      test_pid = self()

      expect(Holter.Integrations.HttpClientMock, :post, 1, fn url, _body, _headers ->
        send(test_pid, {:captured_url, url})
        {:ok, MetaAdsApiFixtures.success_response()}
      end)

      run(integration, payload(ad_sets: ["100000000000333"], ad_set_action: "resume_ad_set"))

      assert_received {:captured_url, "https://graph.facebook.com/v21.0/100000000000333"}
    end

    test "returns :ok and makes no HTTP calls when payload has no targets" do
      integration = integration_with()

      assert :ok = run(integration, %{targets: []})
    end

    test "resumes all campaigns and ad sets from payload on resolved" do
      integration = integration_with()

      stub(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, MetaAdsApiFixtures.success_response()}
      end)

      assert :ok =
               run(
                 integration,
                 payload(
                   campaigns: ["100000000000111", "100000000000222"],
                   ad_sets: ["100000000000333"],
                   campaign_action: "resume_campaign",
                   ad_set_action: "resume_ad_set"
                 )
               )
    end
  end
end
