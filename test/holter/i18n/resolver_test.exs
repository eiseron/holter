defmodule Eiseron.I18n.ResolverTest do
  use ExUnit.Case, async: true

  alias Eiseron.I18n.Resolver

  defp inputs(overrides \\ %{}) do
    Map.merge(
      %{
        url_param: nil,
        user_preferred: nil,
        workspace_default: nil,
        accept_language: nil,
        fallback: "pt_BR"
      },
      overrides
    )
  end

  describe "resolve/1 — tier precedence" do
    test "URL param wins over every other tier when valid" do
      assert Resolver.resolve(
               inputs(%{
                 url_param: "en",
                 user_preferred: "pt_BR",
                 workspace_default: "pt_BR",
                 accept_language: "pt-BR"
               })
             ) == "en"
    end

    test "user preference wins over workspace default and Accept-Language" do
      assert Resolver.resolve(
               inputs(%{
                 user_preferred: "en",
                 workspace_default: "pt_BR",
                 accept_language: "pt-BR"
               })
             ) == "en"
    end

    test "workspace default wins over Accept-Language when no user preference is set" do
      assert Resolver.resolve(
               inputs(%{
                 workspace_default: "en",
                 accept_language: "pt-BR"
               })
             ) == "en"
    end

    test "Accept-Language is used when no DB tier matches" do
      assert Resolver.resolve(inputs(%{accept_language: "pt-BR"})) == "pt_BR"
    end

    test "falls back to the configured app default when nothing else matches" do
      assert Resolver.resolve(inputs()) == "pt_BR"
    end
  end

  describe "resolve/1 — invalid values fall through" do
    test "ignores an unsupported URL param" do
      assert Resolver.resolve(
               inputs(%{
                 url_param: "klingon",
                 user_preferred: "en"
               })
             ) == "en"
    end

    test "ignores an unsupported user preference" do
      assert Resolver.resolve(
               inputs(%{
                 user_preferred: "fr_FR",
                 workspace_default: "en"
               })
             ) == "en"
    end

    test "ignores an unsupported workspace default" do
      assert Resolver.resolve(
               inputs(%{
                 workspace_default: "de_DE",
                 accept_language: "en"
               })
             ) == "en"
    end

    test "ignores garbage Accept-Language entries and falls through to fallback" do
      assert Resolver.resolve(inputs(%{accept_language: ";;,;"})) == "pt_BR"
    end

    test "honors the fallback when every tier is nil or invalid" do
      assert Resolver.resolve(
               inputs(%{
                 url_param: "x",
                 user_preferred: "x",
                 workspace_default: "x",
                 accept_language: "x",
                 fallback: "en"
               })
             ) == "en"
    end
  end

  describe "resolve/1 — missing fallback raises" do
    test "raises KeyError when :fallback is missing" do
      assert_raise KeyError, fn ->
        Resolver.resolve(%{url_param: nil})
      end
    end
  end
end
