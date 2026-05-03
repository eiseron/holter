defmodule HolterWeb.Api.DeliveryLogController do
  use HolterWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import HolterWeb.Api.ParamHelpers

  alias Holter.Delivery
  alias Holter.Delivery.{EmailChannels, WebhookChannels}
  alias HolterWeb.Api.DeliveryLogSchemas

  action_fallback HolterWeb.Api.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, render_error: HolterWeb.Api.OpenApiError

  tags(["Delivery Logs"])

  operation(:index,
    summary: "List delivery logs",
    description:
      "List delivery job logs for a webhook or email channel with pagination and filtering.",
    parameters: [
      webhook_channel_id: [
        in: :path,
        description: "Webhook channel UUID (when listing logs under /webhook_channels)",
        required: false,
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ],
      email_channel_id: [
        in: :path,
        description: "Email channel UUID (when listing logs under /email_channels)",
        required: false,
        schema: %OpenApiSpex.Schema{type: :string, format: "uuid"}
      ],
      page: [
        in: :query,
        description: "Page number",
        schema: %OpenApiSpex.Schema{type: :integer, default: 1}
      ],
      page_size: [
        in: :query,
        description: "Items per page",
        schema: %OpenApiSpex.Schema{type: :integer, default: 50}
      ],
      status: [in: :query, description: "Filter by status: success or failed", type: :string],
      sort_by: [in: :query, description: "Sort column: attempted_at or state", type: :string],
      sort_dir: [in: :query, description: "Sort direction: asc or desc", type: :string]
    ],
    responses: [
      ok: {"Log list", "application/json", DeliveryLogSchemas.delivery_log_list()},
      not_found: {"Channel not found", "application/json", DeliveryLogSchemas.error()}
    ]
  )

  def index(conn, params) do
    with {:ok, channel} <- fetch_channel(params) do
      filters = sanitize_filters(params)
      result = Delivery.list_channel_logs(channel, filters)
      render(conn, :index, logs: result)
    end
  end

  defp fetch_channel(%{webhook_channel_id: id}), do: WebhookChannels.get(id)
  defp fetch_channel(%{email_channel_id: id}), do: EmailChannels.get(id)
  defp fetch_channel(_), do: {:error, :not_found}

  defp sanitize_filters(params) do
    %{}
    |> maybe_put_integer(params, {:page, :page})
    |> maybe_put_integer(params, {:page_size, :page_size})
    |> maybe_put_string(params, {:status, :status})
    |> maybe_put_string(params, {:sort_by, :sort_by})
    |> maybe_put_string(params, {:sort_dir, :sort_dir})
  end
end
