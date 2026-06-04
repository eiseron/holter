defmodule HolterWeb.Api.IntegrationsApiSpec do
  @moduledoc """
  OpenAPI 3.0 specification scoped to the Integrations module.
  """
  @behaviour OpenApiSpex.OpenApi

  alias HolterWeb.Api.{
    IntegrationEventSchemas,
    IntegrationRuleSchemas,
    IntegrationSchemas,
    Security
  }

  alias HolterWeb.Router
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @integrations_path_keywords ~w(integration rule)

  @impl OpenApi
  def spec do
    all_paths = Paths.from_router(Router)

    integrations_paths =
      Map.filter(all_paths, fn {path, _} -> integrations_path?(path) end)

    %OpenApi{
      info: %Info{
        title: "Holter Integrations API",
        version: "1.0.0",
        description:
          "API for third-party integrations: connected providers, bindings, and event audit log."
      },
      servers: [
        %Server{url: "/"}
      ],
      paths: integrations_paths,
      security: Security.requirement(),
      components: %OpenApiSpex.Components{
        securitySchemes: Security.schemes(),
        schemas:
          IntegrationSchemas.all()
          |> Map.merge(IntegrationRuleSchemas.all())
          |> Map.merge(IntegrationEventSchemas.all())
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp integrations_path?(path),
    do: Enum.any?(@integrations_path_keywords, &String.contains?(path, &1))
end
