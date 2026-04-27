defmodule Holter.Delivery.Workers.WebhookDispatcher do
  @moduledoc false

  use Oban.Worker, queue: :notifications, max_attempts: 20

  alias Holter.Delivery.Engine.{ChannelFormatter, PayloadBuilder}
  alias Holter.Delivery.{HttpClient, NotificationChannels, WebhookChannel, WebhookSignature}
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

    headers =
      sign_headers(headers, %{body: body, subtype: channel.webhook_channel, now: now})

    HttpClient.impl().post(channel.target, body, headers)
    :ok
  end

  def perform(%Oban.Job{args: %{"channel_id" => channel_id, "test" => true}}) do
    channel = NotificationChannels.get_channel!(channel_id)
    now = DateTime.utc_now()

    payload = PayloadBuilder.build_test_payload(channel, now)
    {body, headers} = ChannelFormatter.format_payload(payload, channel.type)

    headers =
      sign_headers(headers, %{body: body, subtype: channel.webhook_channel, now: now})

    case HttpClient.impl().post(channel.target, body, headers) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, "webhook returned status #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sign_headers(headers, %{
         body: body,
         subtype: %WebhookChannel{signing_token: token},
         now: %DateTime{} = now
       })
       when is_binary(token) do
    [WebhookSignature.build_signature_header(body, token, now) | headers]
  end

  defp sign_headers(headers, _ctx), do: headers
end
