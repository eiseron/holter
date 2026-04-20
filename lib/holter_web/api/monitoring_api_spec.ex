defmodule HolterWeb.Api.MonitoringApiSpec do
  @moduledoc """
  OpenAPI 3.0 specification scoped to the Monitoring module.
  """
  @behaviour OpenApiSpex.OpenApi

  alias HolterWeb.Api.{
    DailyMetricSchemas,
    IncidentSchemas,
    MonitorLogSchemas,
    MonitorSchemas,
    NotificationChannelSchemas,
    WorkspaceSchemas
  }

  alias HolterWeb.Router
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Holter Monitoring API",
        version: "1.0.0",
        description: "API for monitor management, logs, daily metrics, and incidents."
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
          |> Map.merge(NotificationChannelSchemas.all())
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
