defmodule Holter.Delivery.Workers.WebhookDispatcher do
  @moduledoc false

  use Oban.Worker, queue: :notifications, max_attempts: 20

  alias Holter.Delivery
  alias Holter.Delivery.Engine.{ChannelFormatter, PayloadBuilder}
  alias Holter.Delivery.{HttpClient, NotificationChannels}
  alias Holter.Monitoring

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "channel_id" => channel_id,
          "monitor_id" => monitor_id,
          "incident_id" => incident_id,
          "event" => event
        }
      }) do
    channel = NotificationChannels.get_channel!(channel_id)
    monitor = Monitoring.get_monitor!(monitor_id)
    incident = Monitoring.get_incident!(incident_id)
    now = DateTime.utc_now()

    payload =
      PayloadBuilder.build_incident_payload(monitor, incident, %{
        event: String.to_existing_atom(event),
        now: now
      })

    {body, headers} = ChannelFormatter.format_payload(payload, channel.type)

    result = HttpClient.impl().post(channel.target, body, headers)

    {log_status, log_error} =
      case result do
        {:ok, _} -> {:success, nil}
        {:error, reason} -> {:failed, inspect(reason)}
      end

    Delivery.create_channel_log(%{
      notification_channel_id: channel_id,
      status: log_status,
      event_type: event,
      error_message: log_error,
      monitor_id: monitor_id,
      incident_id: incident_id,
      dispatched_at: now
    })

    :ok
  end

  def perform(%Oban.Job{args: %{"channel_id" => channel_id, "test" => true}}) do
    channel = NotificationChannels.get_channel!(channel_id)
    now = DateTime.utc_now()

    payload = PayloadBuilder.build_test_payload(channel, now)
    {body, headers} = ChannelFormatter.format_payload(payload, channel.type)

    result = HttpClient.impl().post(channel.target, body, headers)

    {log_status, log_error} =
      case result do
        {:ok, %{status: status}} when status in 200..299 -> {:success, nil}
        {:ok, %{status: status}} -> {:failed, "webhook returned status #{status}"}
        {:error, reason} -> {:failed, inspect(reason)}
      end

    Delivery.create_channel_log(%{
      notification_channel_id: channel_id,
      status: log_status,
      event_type: "test",
      error_message: log_error,
      monitor_id: nil,
      incident_id: nil,
      dispatched_at: now
    })

    case result do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, "webhook returned status #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end
end
