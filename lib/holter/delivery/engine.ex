defmodule Holter.Delivery.Engine do
  @moduledoc false

  alias Holter.Delivery.{
    Broadcaster,
    EmailChannel,
    EmailChannels,
    WebhookChannel,
    WebhookChannels
  }

  alias Holter.Delivery.Workers.{EmailDispatcher, WebhookDispatcher}

  @test_dispatch_cooldown 60

  def test_dispatch_cooldown, do: @test_dispatch_cooldown

  def dispatch_incident(monitor_id, incident_id, event) when event in [:down, :up] do
    ctx = %{
      "monitor_id" => monitor_id,
      "incident_id" => incident_id,
      "event" => Atom.to_string(event)
    }

    Enum.each(WebhookChannels.list_for_monitor(monitor_id), fn channel ->
      args =
        ctx
        |> Map.put("webhook_channel_id", channel.id)
        |> Map.put("workspace_id", channel.workspace_id)

      Oban.insert(WebhookDispatcher.new(args))
    end)

    Enum.each(EmailChannels.list_for_monitor(monitor_id), fn channel ->
      args =
        ctx
        |> Map.put("email_channel_id", channel.id)
        |> Map.put("workspace_id", channel.workspace_id)

      Oban.insert(EmailDispatcher.new(args))
    end)

    Broadcaster.broadcast_notification_dispatched(monitor_id, incident_id, event)
  end

  def dispatch_test_webhook(webhook_channel_id) when is_binary(webhook_channel_id) do
    case WebhookChannels.get(webhook_channel_id) do
      {:ok, %WebhookChannel{} = channel} -> do_dispatch_test_webhook(channel)
      error -> error
    end
  end

  def dispatch_test_email(email_channel_id) when is_binary(email_channel_id) do
    case EmailChannels.get(email_channel_id) do
      {:ok, %EmailChannel{} = channel} -> do_dispatch_test_email(channel)
      error -> error
    end
  end

  defp do_dispatch_test_webhook(%WebhookChannel{} = channel) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with :ok <- check_cooldown(channel.last_test_dispatched_at, now) do
      result =
        Oban.insert(
          WebhookDispatcher.new(%{
            "webhook_channel_id" => channel.id,
            "workspace_id" => channel.workspace_id,
            "test" => true
          })
        )

      WebhookChannels.touch_test_dispatched_at(channel, now)
      Broadcaster.broadcast_test_dispatched(channel.id)
      result
    end
  end

  defp do_dispatch_test_email(%EmailChannel{} = channel) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with :ok <- check_cooldown(channel.last_test_dispatched_at, now),
         :ok <- validate_email_test_dispatch(channel) do
      result =
        Oban.insert(
          EmailDispatcher.new(%{
            "email_channel_id" => channel.id,
            "workspace_id" => channel.workspace_id,
            "test" => true
          })
        )

      EmailChannels.touch_test_dispatched_at(channel, now)
      Broadcaster.broadcast_test_dispatched(channel.id)
      result
    end
  end

  defp check_cooldown(nil, _now), do: :ok

  defp check_cooldown(%DateTime{} = last, %DateTime{} = now) do
    if DateTime.diff(now, last, :second) >= @test_dispatch_cooldown,
      do: :ok,
      else: {:error, :test_dispatch_rate_limited}
  end

  defp validate_email_test_dispatch(%EmailChannel{id: id}) do
    case EmailChannels.list_verified_emails(id) do
      [] -> {:error, :no_verified_recipients}
      _ -> :ok
    end
  end
end
