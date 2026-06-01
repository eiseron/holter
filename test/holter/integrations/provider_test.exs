defmodule Holter.Integrations.ProviderTest do
  use ExUnit.Case, async: true

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
end
