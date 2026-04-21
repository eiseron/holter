defmodule HolterWeb.Api.DeliveryApiSpec do
  @moduledoc """
  OpenAPI 3.0 specification scoped to the Delivery module.
  """
  @behaviour OpenApiSpex.OpenApi

  alias HolterWeb.Api.NotificationChannelSchemas
  alias HolterWeb.Router
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @impl OpenApi
  def spec do
    all_paths = Paths.from_router(Router)

    delivery_paths =
      Map.filter(all_paths, fn {path, _} -> String.contains?(path, "notification_channel") end)

    %OpenApi{
      info: %Info{
        title: "Holter Delivery API",
        version: "1.0.0",
        description: "API for notification channel management and alert dispatch."
      },
      servers: [
        %Server{url: "/"}
      ],
      paths: delivery_paths,
      components: %OpenApiSpex.Components{
        schemas: NotificationChannelSchemas.all()
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
