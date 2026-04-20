defmodule Holter.Delivery.EventConsumer do
  @moduledoc false

  use GenServer

  alias Holter.Delivery.Engine

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl GenServer
  def init(_opts) do
    Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:incidents")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info({:incident_opened, incident}, state) do
    Engine.dispatch_incident(incident.monitor_id, incident.id, :down)
    {:noreply, state}
  end

  def handle_info({:incident_resolved, incident}, state) do
    Engine.dispatch_incident(incident.monitor_id, incident.id, :up)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
