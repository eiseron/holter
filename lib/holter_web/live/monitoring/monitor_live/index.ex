defmodule HolterWeb.Monitoring.MonitorLive.Index do
  use HolterWeb, :live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"org_slug" => slug}, _session, socket) do
    case Monitoring.get_organization_by_slug(slug) do
      {:ok, org} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitors")
        end

        {:ok,
         socket
         |> assign(:org, org)
         |> assign(:monitors, Monitoring.list_monitors_by_organization(org.id))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Organization not found")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    {:noreply,
     assign(socket, monitors: Monitoring.list_monitors_by_organization(socket.assigns.org.id))}
  end
end
