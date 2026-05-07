defmodule HolterWeb.StaticCachePolicyTest do
  use ExUnit.Case, async: true

  alias HolterWeb.StaticCachePolicy

  describe "etag_cache_control/1" do
    test "returns no-cache when code reloading is enabled" do
      assert StaticCachePolicy.etag_cache_control(true) == "no-cache"
    end

    test "returns public 1-day cache when code reloading is disabled" do
      assert StaticCachePolicy.etag_cache_control(false) == "public, max-age=86400"
    end
  end

  describe "vsn_cache_control/1" do
    test "returns no-cache when code reloading is enabled" do
      assert StaticCachePolicy.vsn_cache_control(true) == "no-cache"
    end

    test "returns public immutable 1-year cache when code reloading is disabled" do
      assert StaticCachePolicy.vsn_cache_control(false) ==
               "public, max-age=31536000, immutable"
    end
  end
end
