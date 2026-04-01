defmodule HolterWeb.Monitoring.MonitorLive.Index do
  use HolterWeb, :live_view

  alias Holter.Monitoring

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, monitors: Monitoring.list_monitors())}
  end
end
