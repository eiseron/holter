defmodule Mix.Tasks.Holter.GenApiDocsTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Holter.GenApiDocs

  setup do
    original_env = Application.get_env(:holter, :api_specs, [])
    original_shell = Mix.shell()

    Mix.shell(Mix.Shell.Quiet)

    on_exit(fn ->
      Application.put_env(:holter, :api_specs, original_env)
      Mix.shell(original_shell)
    end)

    :ok
  end

  defp tmp_path(filename) do
    Path.join(System.tmp_dir!(), filename)
  end

  describe "run/1 with empty config" do
    test "completes without error when no specs are configured" do
      Application.put_env(:holter, :api_specs, [])
      assert GenApiDocs.run([]) == :ok
    end
  end

  describe "run/1 with ApiSpec" do
    setup do
      output = tmp_path("holter_test_openapi.yml")
      Application.put_env(:holter, :api_specs, [{HolterWeb.Api.ApiSpec, output}])
      GenApiDocs.run([])
      on_exit(fn -> File.rm(output) end)
      %{output: output}
    end

    test "generates the output file", %{output: output} do
      assert File.exists?(output)
    end

    test "generated file contains valid openapi content", %{output: output} do
      content = File.read!(output)
      assert String.starts_with?(content, "---") or String.contains?(content, "openapi:")
    end
  end

  describe "run/1 with MonitoringApiSpec" do
    setup do
      output = tmp_path("holter_test_monitoring.yml")
      Application.put_env(:holter, :api_specs, [{HolterWeb.Api.MonitoringApiSpec, output}])
      GenApiDocs.run([])
      on_exit(fn -> File.rm(output) end)
      %{output: output}
    end

    test "generates the output file", %{output: output} do
      assert File.exists?(output)
    end
  end

  describe "run/1 with multiple specs" do
    setup do
      output1 = tmp_path("holter_test_multi_openapi.yml")
      output2 = tmp_path("holter_test_multi_monitoring.yml")

      Application.put_env(:holter, :api_specs, [
        {HolterWeb.Api.ApiSpec, output1},
        {HolterWeb.Api.MonitoringApiSpec, output2}
      ])

      GenApiDocs.run([])

      on_exit(fn ->
        File.rm(output1)
        File.rm(output2)
      end)

      %{output1: output1, output2: output2}
    end

    test "generates the first spec file", %{output1: output1} do
      assert File.exists?(output1)
    end

    test "generates the second spec file", %{output2: output2} do
      assert File.exists?(output2)
    end
  end
end
