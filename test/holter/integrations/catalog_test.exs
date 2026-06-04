defmodule Holter.Integrations.CatalogTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Catalog

  @registry %{
    google_ads: Holter.Integrations.Google.Ads,
    meta_ads: Holter.Integrations.Meta.Ads
  }

  describe "build_catalog/1" do
    test "returns a list of provider entries" do
      catalog = Catalog.build_catalog(@registry)

      assert is_list(catalog)
    end

    test "returns one entry per registered provider" do
      catalog = Catalog.build_catalog(@registry)

      assert length(catalog) == 2
    end

    test "each entry has the :provider key" do
      catalog = Catalog.build_catalog(@registry)

      assert Enum.all?(catalog, &Map.has_key?(&1, :provider))
    end

    test "each entry has the :display_name pulled from the provider module" do
      catalog = Catalog.build_catalog(@registry)

      entry = Enum.find(catalog, &(&1.provider == :google_ads))
      assert entry.display_name == "Google Ads"
    end

    test "each entry has the :category pulled from the provider module" do
      catalog = Catalog.build_catalog(@registry)

      entry = Enum.find(catalog, &(&1.provider == :meta_ads))
      assert entry.category == :ads
    end

    test "each entry has the :icon pulled from the provider module" do
      catalog = Catalog.build_catalog(@registry)

      entry = Enum.find(catalog, &(&1.provider == :google_ads))
      assert entry.icon == "google_ads"
    end

    test "entries are sorted alphabetically by display_name" do
      catalog = Catalog.build_catalog(@registry)

      assert Enum.map(catalog, & &1.display_name) == ["Google Ads", "Meta Ads"]
    end

    test "an empty registry yields an empty catalog" do
      catalog = Catalog.build_catalog(%{})

      assert catalog == []
    end
  end

  describe "build_catalog/2" do
    test "merges connected integrations into matching catalog entries" do
      integration = %{provider: :google_ads, id: "gads-1", status: :active}

      catalog = Catalog.build_catalog(@registry, [integration])

      entry = Enum.find(catalog, &(&1.provider == :google_ads))
      assert entry.integration.id == "gads-1"
    end

    test "entries without a matching integration have integration set to nil" do
      catalog = Catalog.build_catalog(@registry, [])

      for entry <- catalog do
        assert entry.integration == nil
      end
    end

    test "partial match leaves unmatched providers with nil integration" do
      integration = %{provider: :google_ads, id: "gads-1", status: :active}

      catalog = Catalog.build_catalog(@registry, [integration])

      meta_entry = Enum.find(catalog, &(&1.provider == :meta_ads))
      assert meta_entry.integration == nil
    end

    test "integrations for unregistered providers are ignored" do
      integration = %{provider: :slack, id: "slack-1", status: :active}

      catalog = Catalog.build_catalog(@registry, [integration])

      assert Enum.all?(catalog, &(&1.provider != :slack))
    end
  end
end
