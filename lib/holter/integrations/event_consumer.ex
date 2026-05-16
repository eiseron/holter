defmodule Holter.Integrations.EventConsumer do
  @moduledoc false

  use GenServer

  alias Holter.Integrations.Engine

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl GenServer
  def init(_opts) do
    Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:incidents")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info({:incident_opened, incident}, state) do
    Engine.dispatch_event(incident, "incident_opened")
    {:noreply, state}
  end

  def handle_info({:incident_resolved, incident}, state) do
    Engine.dispatch_event(incident, "incident_resolved")
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
