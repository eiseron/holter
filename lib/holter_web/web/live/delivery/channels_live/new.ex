defmodule HolterWeb.Web.Delivery.ChannelsLive.New do
  use HolterWeb, :workspace_live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, gettext("New Channel"))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end
end
