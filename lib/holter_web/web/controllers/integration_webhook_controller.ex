defmodule HolterWeb.Web.Integrations.IntegrationWebhookController do
  @moduledoc false

  use HolterWeb, :controller

  alias Holter.Integrations.Provider
  alias Holter.Integrations.WebhookReceiver

  def receive(conn, %{"workspace_slug" => workspace_slug, "provider" => provider_str}) do
    case Provider.cast_provider(provider_str) do
      {:ok, provider} -> process_and_respond(conn, workspace_slug, provider)
      {:error, _} -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end

  defp process_and_respond(conn, workspace_slug, provider) do
    request = %{
      provider: provider,
      params: conn.params,
      verified?: conn.private[:webhook_verified] == true
    }

    case WebhookReceiver.process_inbound(workspace_slug, request) do
      {:ok, status} when status in [:processed, :ignored] ->
        json(conn, %{ok: true})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, _reason} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "internal_error"})
    end
  end
end
