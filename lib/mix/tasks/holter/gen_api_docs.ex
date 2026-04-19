defmodule Mix.Tasks.Holter.GenApiDocs do
  use Mix.Task

  @shortdoc "Generate OpenAPI YAML docs for all configured API modules"

  @impl Mix.Task
  def run(_args) do
    specs = Application.get_env(:holter, :api_specs, [])

    Enum.each(specs, fn {spec_module, output_path} ->
      Mix.Task.run("openapi.spec.yaml", ["--spec", inspect(spec_module), "--output", output_path])
      Mix.Task.reenable("openapi.spec.yaml")
    end)
  end
end
