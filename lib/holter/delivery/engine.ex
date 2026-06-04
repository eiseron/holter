defmodule Holter.Delivery.Engine do
  @moduledoc false

  alias Holter.Delivery.{Broadcaster, EmailChannels, WebhookChannels}

  alias Holter.Delivery.Models.{EmailChannel, WebhookChannel}
  alias Holter.Delivery.Workers.{EmailDispatcher, WebhookDispatcher}
  alias Holter.Repo.Tenant

  require Logger

  @test_dispatch_cooldown 60

  def test_dispatch_cooldown, do: @test_dispatch_cooldown

  def dispatch_incident(%{workspace_id: workspace_id} = incident, event)
      when event in [:down, :up] and is_binary(workspace_id) do
    Tenant.with_workspace!(workspace_id, fn ->
      do_dispatch_incident(incident, event, workspace_id)
    end)
  end

  def dispatch_incident(incident, event) when event in [:down, :up] do
    Logger.warning(
      "delivery: incident #{inspect(Map.get(incident, :id))} missing workspace_id; skipping dispatch"
    )

    :ok
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

  defp do_dispatch_incident(incident, event, workspace_id) do
    ctx = %{
      "monitor_id" => incident.monitor_id,
      "incident_id" => incident.id,
      "workspace_id" => workspace_id,
      "event" => Atom.to_string(event)
    }

    Enum.each(WebhookChannels.list_for_monitor(incident.monitor_id), fn channel ->
      Oban.insert(WebhookDispatcher.new(Map.put(ctx, "webhook_channel_id", channel.id)))
    end)

    Enum.each(EmailChannels.list_for_monitor(incident.monitor_id), fn channel ->
      Oban.insert(EmailDispatcher.new(Map.put(ctx, "email_channel_id", channel.id)))
    end)

    Broadcaster.broadcast_notification_dispatched(incident.monitor_id, incident.id, event)
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
