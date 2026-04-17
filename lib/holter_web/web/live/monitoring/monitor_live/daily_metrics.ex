defmodule HolterWeb.Web.Monitoring.MonitorLive.DailyMetrics do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
    end

    monitor = Monitoring.get_monitor!(id)
    daily_metrics = Monitoring.list_daily_metrics(id)

    {:ok,
     socket
     |> assign(:monitor, monitor)
     |> assign(:daily_metrics, daily_metrics)}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [
             :log_created,
             :metric_updated,
             :monitor_updated,
             :incident_created,
             :incident_resolved,
             :incident_updated
           ] do
    {:noreply,
     assign(socket, :daily_metrics, Monitoring.list_daily_metrics(socket.assigns.monitor.id))}
  end
end
