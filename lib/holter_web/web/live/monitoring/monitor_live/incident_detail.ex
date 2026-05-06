defmodule HolterWeb.Web.Monitoring.MonitorLive.IncidentDetail do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring
  alias Holter.Repo.Tenant
  alias HolterWeb.LiveView.PubSubSubscriptions

  @impl true
  def mount(_params, _session, socket) do
    incident = socket.assigns.current_incident
    monitor = socket.assigns.current_monitor

    PubSubSubscriptions.subscribe_to_monitor(socket, monitor.id)

    logs = Monitoring.list_logs_by_incident(incident.id)
    logs_total = Monitoring.count_logs_by_incident(incident.id)

    {:ok,
     socket
     |> assign(:incident, incident)
     |> assign(:monitor, monitor)
     |> assign(:logs, logs)
     |> assign(:logs_total, logs_total)
     |> assign(:page_title, gettext("Incident Details"))}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [:incident_updated, :incident_resolved] do
    workspace_id = socket.assigns.monitor.workspace_id

    incident =
      Tenant.with_workspace!(workspace_id, fn ->
        Monitoring.get_incident!(socket.assigns.incident.id)
      end)

    {:noreply, assign(socket, :incident, incident)}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}
end
