defmodule HolterWeb.ApiSpec do
  @moduledoc """
  OpenAPI 3.0 specification for the Holter API.
  """
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
        %Server{url: "http://localhost:4000/api"}
      ],
      paths: Paths.from_router(Router),
      components: %OpenApiSpex.Components{
        schemas: HolterWeb.MonitorSchemas.all()
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
