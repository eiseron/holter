defmodule HolterWeb.Monitoring.MonitorLive.Index do
  use HolterWeb, :live_view

  alias Holter.Monitoring

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitors")
    end

    {:ok, assign(socket, monitors: Monitoring.list_monitors())}
  end

  @impl true
  def handle_info({_event, _data}, socket) do
    {:noreply, assign(socket, monitors: Monitoring.list_monitors())}
  end
end
