defmodule Holter.Delivery.Engine do
  @moduledoc false

  alias Holter.Delivery.NotificationChannels
  alias Holter.Delivery.Workers.{EmailDispatcher, WebhookDispatcher}

  def dispatch_incident(monitor_id, incident_id, event) when event in [:down, :up] do
    channels = NotificationChannels.list_channels_for_monitor(monitor_id)

    ctx = %{
      "monitor_id" => monitor_id,
      "incident_id" => incident_id,
      "event" => Atom.to_string(event)
    }

    Enum.each(channels, &enqueue_for_channel(&1, ctx))
  end

  def dispatch_test(channel_id) do
    channel = NotificationChannels.get_channel!(channel_id)
    enqueue_test_for_channel(channel)
  end

  defp enqueue_for_channel(channel, ctx) do
    args = Map.put(ctx, "channel_id", channel.id)
    channel.type |> worker_module() |> then(fn w -> Oban.insert(w.new(args)) end)
  end

  defp enqueue_test_for_channel(channel) do
    args = %{"channel_id" => channel.id, "test" => true}
    channel.type |> worker_module() |> then(fn w -> Oban.insert(w.new(args)) end)
  end

  defp worker_module(:email), do: EmailDispatcher
  defp worker_module(_), do: WebhookDispatcher
end
