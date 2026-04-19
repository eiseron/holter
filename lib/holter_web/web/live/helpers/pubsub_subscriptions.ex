defmodule HolterWeb.LiveView.PubSubSubscriptions do
  @moduledoc false

  def subscribe_to_monitor(socket, id) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
    end

    :ok
  end

  def subscribe_to_monitors(socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitors")
    end

    :ok
  end
end
