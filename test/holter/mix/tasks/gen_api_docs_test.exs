defmodule Mix.Tasks.Holter.GenApiDocsTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Holter.GenApiDocs

  setup do
    original = Application.get_env(:holter, :api_specs, [])
    on_exit(fn -> Application.put_env(:holter, :api_specs, original) end)
    :ok
  end

  describe "run/1 with empty config" do
    test "completes without error when no specs are configured" do
      Application.put_env(:holter, :api_specs, [])
      assert GenApiDocs.run([]) == :ok
    end
  end

  describe "run/1 with real spec" do
    test "generates docs/api/openapi.yml from the root ApiSpec" do
      output = "docs/api/openapi.yml"

      Application.put_env(:holter, :api_specs, [
        {HolterWeb.Api.ApiSpec, output}
      ])

      GenApiDocs.run([])

      assert File.exists?(output), "Expected #{output} to be generated"
    end

    test "generated openapi.yml contains valid openapi content" do
      output = "docs/api/openapi.yml"

      Application.put_env(:holter, :api_specs, [
        {HolterWeb.Api.ApiSpec, output}
      ])

      GenApiDocs.run([])

      content = File.read!(output)
      assert String.starts_with?(content, "---") or String.contains?(content, "openapi:")
    end

    test "generates docs/api/monitoring.yml from the MonitoringApiSpec" do
      output = "docs/api/monitoring.yml"

      Application.put_env(:holter, :api_specs, [
        {HolterWeb.Api.MonitoringApiSpec, output}
      ])

      GenApiDocs.run([])

      assert File.exists?(output), "Expected #{output} to be generated"
    end

    test "generates all configured specs in sequence" do
      outputs = ["docs/api/openapi.yml", "docs/api/monitoring.yml"]

      Application.put_env(:holter, :api_specs, [
        {HolterWeb.Api.ApiSpec, Enum.at(outputs, 0)},
        {HolterWeb.Api.MonitoringApiSpec, Enum.at(outputs, 1)}
      ])

      GenApiDocs.run([])

      for output <- outputs do
        assert File.exists?(output), "Expected #{output} to be generated"
      end
    end
  end
end
