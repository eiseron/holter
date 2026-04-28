defmodule Holter.Delivery.Engine do
  @moduledoc false

  alias Holter.Delivery.{Broadcaster, EmailChannel, NotificationChannel, NotificationChannels}
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

    case validate_test_dispatch(channel) do
      :ok ->
        result = enqueue_test_for_channel(channel)
        Broadcaster.broadcast_test_dispatched(channel_id)
        result

      {:error, _} = error ->
        error
    end
  end

  defp validate_test_dispatch(%NotificationChannel{type: :email} = channel) do
    if has_any_verified_address?(channel),
      do: :ok,
      else: {:error, :no_verified_recipients}
  end

  defp validate_test_dispatch(_), do: :ok

  defp has_any_verified_address?(%NotificationChannel{} = channel) do
    primary_verified? = EmailChannel.verified?(channel.email_channel)
    primary_verified? or NotificationChannels.list_verified_emails(channel.id) != []
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
