defmodule Holter.Delivery.Engine do
  @moduledoc false

  alias Holter.Delivery.{Broadcaster, NotificationChannel, NotificationChannels}
  alias Holter.Delivery.Workers.{EmailDispatcher, WebhookDispatcher}

  def dispatch_incident(monitor_id, incident_id, event) when event in [:down, :up] do
    channels = NotificationChannels.list_channels_for_monitor(monitor_id)

    ctx = %{
      "monitor_id" => monitor_id,
      "incident_id" => incident_id,
      "event" => Atom.to_string(event)
    }

    Enum.each(channels, &enqueue_for_channel(&1, ctx))
    Broadcaster.broadcast_notification_dispatched(monitor_id, incident_id, event)
  end

  def dispatch_test(channel_id) do
    channel = NotificationChannels.get_channel!(channel_id)
    result = enqueue_test_for_channel(channel)
    Broadcaster.broadcast_test_dispatched(channel_id)
    result
  end

  defp enqueue_for_channel(channel, ctx) do
    args = Map.put(ctx, "channel_id", channel.id)
    channel |> worker_module() |> then(fn w -> Oban.insert(w.new(args)) end)
  end

  defp enqueue_test_for_channel(channel) do
    args = %{"channel_id" => channel.id, "test" => true}
    channel |> worker_module() |> then(fn w -> Oban.insert(w.new(args)) end)
  end

  defp worker_module(%NotificationChannel{} = channel) do
    case NotificationChannel.type(channel) do
      :email -> EmailDispatcher
      :webhook -> WebhookDispatcher
    end
  end
end
