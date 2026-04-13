defmodule HolterWeb.Api.ApiSpec do
  @moduledoc """
  OpenAPI 3.0 specification for the Holter API.
  """
  alias HolterWeb.Api.{
    DailyMetricSchemas,
    IncidentSchemas,
    MonitorLogSchemas,
    MonitorSchemas,
    WorkspaceSchemas
  }

  alias HolterWeb.Router
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Holter API",
        version: "1.0.0",
        description: "API for monitoring and security scanning."
      },
      servers: [
        %Server{url: "/"}
      ],
      paths: Paths.from_router(Router),
      components: %OpenApiSpex.Components{
        schemas:
          MonitorSchemas.all()
          |> Map.merge(WorkspaceSchemas.all())
          |> Map.merge(MonitorLogSchemas.all())
          |> Map.merge(DailyMetricSchemas.all())
          |> Map.merge(IncidentSchemas.all())
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
