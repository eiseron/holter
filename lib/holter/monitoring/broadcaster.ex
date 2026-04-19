defmodule Holter.Monitoring.Broadcaster do
  @moduledoc false

  def broadcast({:ok, entity}, event, monitor_id) do
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitor:#{monitor_id}", {event, entity})
    Phoenix.PubSub.broadcast(Holter.PubSub, "monitoring:monitors", {event, entity})
    {:ok, entity}
  end

  def broadcast(error, _event, _monitor_id), do: error
end
