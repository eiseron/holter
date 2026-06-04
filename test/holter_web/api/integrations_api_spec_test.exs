defmodule HolterWeb.Api.IntegrationsApiSpecTest do
  use ExUnit.Case, async: true

  alias HolterWeb.Api.IntegrationsApiSpec

  describe "spec/0" do
    test "spec title is Holter Integrations API" do
      assert IntegrationsApiSpec.spec().info.title == "Holter Integrations API"
    end

    test "only integration paths are included" do
      assert Enum.all?(Map.keys(IntegrationsApiSpec.spec().paths), fn path ->
               String.contains?(path, "integration") or String.contains?(path, "rule")
             end)
    end

    test "schemas include an Integration entry" do
      assert Enum.any?(
               Map.keys(IntegrationsApiSpec.spec().components.schemas),
               &String.contains?(&1, "Integration")
             )
    end

    test "schemas include an IntegrationRule entry" do
      assert Enum.any?(
               Map.keys(IntegrationsApiSpec.spec().components.schemas),
               &String.contains?(&1, "IntegrationRule")
             )
    end

    test "schemas include an IntegrationEvent entry" do
      assert Enum.any?(
               Map.keys(IntegrationsApiSpec.spec().components.schemas),
               &String.contains?(&1, "IntegrationEvent")
             )
    end
  end
end
