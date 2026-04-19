defmodule HolterWeb.Web.Monitoring.MonitorLive.IncidentDetail do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring
  alias HolterWeb.LiveView.PubSubSubscriptions

  @impl true
  def mount(%{"incident_id" => incident_id}, _session, socket) do
    incident = Monitoring.get_incident!(incident_id)
    monitor = Monitoring.get_monitor!(incident.monitor_id)

    PubSubSubscriptions.subscribe_to_monitor(socket, monitor.id)

    {:ok,
     socket
     |> assign(:incident, incident)
     |> assign(:monitor, monitor)
     |> assign(:page_title, gettext("Incident Details"))}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [:incident_updated, :incident_resolved] do
    incident = Monitoring.get_incident!(socket.assigns.incident.id)
    {:noreply, assign(socket, :incident, incident)}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}
end
