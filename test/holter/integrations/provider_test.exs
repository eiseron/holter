defmodule Holter.Integrations.ProviderTest do
  use ExUnit.Case, async: false

  alias Holter.Integrations.Provider

  describe "cast_provider/1" do
    test "returns {:ok, atom} for a known provider string" do
      assert {:ok, :google_ads} = Provider.cast_provider("google_ads")
    end

    test "returns {:error, :unknown_provider} for an unknown string" do
      assert {:error, :unknown_provider} = Provider.cast_provider("not_a_provider")
    end

    test "returns {:error, :unknown_provider} for an empty string" do
      assert {:error, :unknown_provider} = Provider.cast_provider("")
    end
  end

  describe "provider_module/1" do
    test "returns {:error, :not_implemented} for unregistered providers" do
      assert {:error, :not_implemented} = Provider.provider_module(:unknown_provider)
    end

    test "returns {:ok, module} for a registered provider" do
      Application.put_env(:holter, :integration_providers, %{test_stub: __MODULE__})
      on_exit(fn -> Application.delete_env(:holter, :integration_providers) end)

      assert {:ok, __MODULE__} = Provider.provider_module(:test_stub)
    end
  end

  describe "format_action_label/2" do
    setup do
      Application.put_env(:holter, :integration_providers, %{
        google_ads: Holter.Integrations.Google.Ads,
        meta_ads: Holter.Integrations.Meta.Ads
      })

      on_exit(fn -> Application.delete_env(:holter, :integration_providers) end)
    end

    test "returns translated label for a provider-specific action" do
      assert Provider.format_action_label(:google_ads, "pause_campaign") == "Pause campaign"
    end

    test "returns translated label for a cross-cutting event name" do
      assert Provider.format_action_label(:google_ads, "incident_opened") == "Incident opened"
    end

    test "returns translated label for incident_resolved" do
      assert Provider.format_action_label(:meta_ads, "incident_resolved") == "Incident resolved"
    end

    test "returns translated label for meta-specific action" do
      assert Provider.format_action_label(:meta_ads, "pause_ad_set") == "Pause ad set"
    end

    test "returns raw action string for unknown actions" do
      assert Provider.format_action_label(:google_ads, "unknown_action") == "unknown_action"
    end

    test "falls back to event label map when provider is not registered" do
      assert Provider.format_action_label(:unknown_provider, "incident_opened") ==
               "Incident opened"
    end

    test "returns raw string for unknown actions on unregistered provider" do
      assert Provider.format_action_label(:unknown_provider, "some_action") == "some_action"
    end
  end
end
