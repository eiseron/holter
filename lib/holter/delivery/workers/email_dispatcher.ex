defmodule Holter.Delivery.Workers.EmailDispatcher do
  @moduledoc false

  use Oban.Worker, queue: :notifications, max_attempts: 20

  import Swoosh.Email

  alias Holter.Delivery.Engine.{ChannelFormatter, PayloadBuilder}
  alias Holter.Delivery.NotificationChannels
  alias Holter.Mailer
  alias Holter.Monitoring

  @from_address "alerts@holter.io"

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

    {subject, body} = ChannelFormatter.format_payload(payload, :email)

    new()
    |> to(channel.target)
    |> from(@from_address)
    |> subject(subject)
    |> text_body(body)
    |> Mailer.deliver()

    :ok
  end

  def perform(%Oban.Job{args: %{"channel_id" => channel_id, "test" => true}}) do
    channel = NotificationChannels.get_channel!(channel_id)
    now = DateTime.utc_now()

    payload = PayloadBuilder.build_test_payload(channel, now)
    {subject, body} = ChannelFormatter.format_payload(payload, :email)

    email =
      new()
      |> to(channel.target)
      |> from(@from_address)
      |> subject(subject)
      |> text_body(body)

    Mailer.deliver(email)
    :ok
  end
end
