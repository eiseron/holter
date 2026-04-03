defmodule HolterWeb.Monitoring.MonitorLive.Logs do
  use HolterWeb, :live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
    end

    monitor = Monitoring.get_monitor!(id)
    logs = Monitoring.list_monitor_logs(id)

    {:ok,
     socket
     |> assign(:monitor, monitor)
     |> assign(:logs, logs)
     |> assign(:selected_log, nil)}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [
             :log_created,
             :monitor_updated,
             :incident_created,
             :incident_resolved,
             :incident_updated
           ] do
    {:noreply, assign(socket, logs: Monitoring.list_monitor_logs(socket.assigns.monitor.id))}
  end

  @impl true
  def handle_event("view_evidence", %{"id" => log_id}, socket) do
    log = Monitoring.get_monitor_log!(log_id)
    {:noreply, assign(socket, :selected_log, log)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :selected_log, nil)}
  end
end
