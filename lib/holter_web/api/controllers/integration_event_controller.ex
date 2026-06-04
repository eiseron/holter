defmodule HolterWeb.Api.IntegrationEventController do
  @moduledoc """
  REST API controller for integration events (append-only audit log).

  Only `:index` (paginated, scoped to a parent integration) and `:show` are
  exposed — events are immutable, so no create/update/delete actions exist.
  """
  use HolterWeb, :controller
  use HolterWeb.ApiTenancy
  use OpenApiSpex.ControllerSpecs

  import HolterWeb.Api.ParamHelpers

  alias Holter.Integrations
  alias HolterWeb.Api.IntegrationEventSchemas
  alias HolterWeb.Plugs.RequireScopePlug

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError
  plug RequireScopePlug, "read:integrations" when action in [:index, :show]

  tags(["Integration Events"])

  operation(:index,
    summary: "List integration events",
    description:
      "List dispatch/webhook events for an integration with pagination. Defaults to 25 per page.",
    parameters: [
      integration_id: [
        in: :path,
        description: "Integration UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ],
      page: [
        in: :query,
        description: "Page number",
        schema: %OpenApiSpex.Schema{type: :integer, default: 1}
      ],
      page_size: [
        in: :query,
        description: "Items per page (max 100)",
        schema: %OpenApiSpex.Schema{type: :integer, default: 25}
      ]
    ],
    responses: [
      ok: {"Event list", "application/json", IntegrationEventSchemas.integration_event_list()},
      not_found: {"Integration not found", "application/json", IntegrationEventSchemas.error()}
    ]
  )

  def index(conn, %{integration_id: integration_id} = params) do
    actor = conn.assigns.current_user

    with {:ok, integration} <- Integrations.get_integration(integration_id),
         :ok <- authorize(actor, :read, integration) do
      filters = sanitize_filters(params)
      events = Integrations.list_integration_events_page(integration.id, filters)
      render(conn, :index, events: events)
    end
  end

  operation(:show,
    summary: "Get integration event",
    description: "Fetch a single integration event by its UUID.",
    parameters: [
      id: [
        in: :path,
        description: "Event UUID",
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ]
    ],
    responses: [
      ok: {"Event", "application/json", IntegrationEventSchemas.integration_event_response()},
      not_found: {"Event not found", "application/json", IntegrationEventSchemas.error()}
    ]
  )

  def show(conn, %{id: id}) do
    actor = conn.assigns.current_user

    with {:ok, event} <- Integrations.get_integration_event(id),
         {:ok, integration} <- Integrations.get_integration(event.integration_id),
         :ok <- authorize(actor, :read, integration) do
      render(conn, :show, event: event)
    end
  end

  defp sanitize_filters(params) do
    %{}
    |> maybe_put_integer(params, {:page, :page})
    |> maybe_put_integer(params, {:page_size, :page_size})
  end
end
