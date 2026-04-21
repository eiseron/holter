defmodule Holter.Delivery.Broadcaster do
  @moduledoc false

  def broadcast_notification_dispatched(monitor_id, incident_id, event) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "delivery:notifications",
      {:notification_dispatched,
       %{monitor_id: monitor_id, incident_id: incident_id, event: event}}
    )
  end

  def broadcast_test_dispatched(channel_id) do
    Phoenix.PubSub.broadcast(
      Holter.PubSub,
      "delivery:notifications",
      {:test_dispatched, %{channel_id: channel_id}}
    )
  end
end
