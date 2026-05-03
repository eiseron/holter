defmodule HolterWeb.Api.DeliveryApiSpec do
  @moduledoc """
  OpenAPI 3.0 specification scoped to the Delivery module.
  """
  @behaviour OpenApiSpex.OpenApi

  alias HolterWeb.Api.{
    DeliveryLogSchemas,
    EmailChannelSchemas,
    WebhookChannelSchemas
  }

  alias HolterWeb.Router
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @delivery_path_keywords ~w(webhook_channel email_channel)

  @impl OpenApi
  def spec do
    all_paths = Paths.from_router(Router)

    delivery_paths =
      Map.filter(all_paths, fn {path, _} -> delivery_path?(path) end)

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
        schemas:
          WebhookChannelSchemas.all()
          |> Map.merge(EmailChannelSchemas.all())
          |> Map.merge(DeliveryLogSchemas.all())
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp delivery_path?(path),
    do: Enum.any?(@delivery_path_keywords, &String.contains?(path, &1))
end
