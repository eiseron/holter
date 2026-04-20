defmodule Mix.Tasks.Holter.GenApiDocs do
  @moduledoc """
  Generates OpenAPI YAML specification files for all configured API modules.

  Reads the `:api_specs` config (a list of `{spec_module, output_path}` tuples)
  and runs `mix openapi.spec.yaml` for each entry.
  """

  @shortdoc "Generate OpenAPI YAML docs for all configured API modules"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    specs = Application.get_env(:holter, :api_specs, [])

    Enum.each(specs, fn {spec_module, output_path} ->
      Mix.Task.run("openapi.spec.yaml", ["--spec", inspect(spec_module), "--output", output_path])
      Mix.Task.reenable("openapi.spec.yaml")
    end)
  end
end
