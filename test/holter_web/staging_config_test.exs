defmodule HolterWeb.StagingConfigTest do
  use ExUnit.Case, async: true

  @staging_config Path.expand("../../config/staging.exs", __DIR__)

  defp read_staging do
    Config.Reader.read!(@staging_config, env: :staging)
  end

  describe "config/staging.exs (review-app environment)" do
    test "produces a digested asset manifest like prod" do
      endpoint = read_staging()[:holter][HolterWeb.Endpoint]
      assert endpoint[:cache_static_manifest] == "priv/static/cache_manifest.json"
    end

    test "inherits force_ssl rewrite_on x_forwarded_proto from prod" do
      endpoint = read_staging()[:holter][HolterWeb.Endpoint]
      assert endpoint[:force_ssl][:rewrite_on] == [:x_forwarded_proto]
    end

    test "uses prod swoosh Req api client" do
      assert read_staging()[:swoosh][:api_client] == Swoosh.ApiClient.Req
    end

    test "disables swoosh local memory storage" do
      assert read_staging()[:swoosh][:local] == false
    end

    test "keeps debug_errors enabled so review-app 500s show a stack trace" do
      endpoint = read_staging()[:holter][HolterWeb.Endpoint]
      assert endpoint[:debug_errors] == true
    end

    test "logger level is :debug so review-app logs are verbose" do
      assert read_staging()[:logger][:level] == :debug
    end

    test "does not enable code_reloader (no runtime recompile)" do
      endpoint = read_staging()[:holter][HolterWeb.Endpoint]
      refute endpoint[:code_reloader]
    end

    test "does not configure live_reload (no WebSocket frame)" do
      endpoint = read_staging()[:holter][HolterWeb.Endpoint]
      refute endpoint[:live_reload]
    end

    test "does not run esbuild watchers" do
      endpoint = read_staging()[:holter][HolterWeb.Endpoint]
      refute endpoint[:watchers]
    end
  end
end
