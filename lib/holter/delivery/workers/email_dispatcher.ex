defmodule Holter.Delivery.Workers.EmailDispatcher do
  @moduledoc false

  use Oban.Worker, queue: :notifications, max_attempts: 20

  import Swoosh.Email

  alias Holter.Delivery
  alias Holter.Delivery.Engine.{ChannelFormatter, PayloadBuilder}
  alias Holter.Delivery.NotificationChannels
  alias Holter.Mailers.AlertMailer
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

    {subject, body} = ChannelFormatter.format_payload(payload, :email)
    cc_emails = NotificationChannels.list_verified_emails(channel_id)

    result =
      new()
      |> to(channel.target)
      |> from(from_address())
      |> then(fn email -> Enum.reduce(cc_emails, email, &cc(&2, &1)) end)
      |> subject(subject)
      |> text_body(body)
      |> AlertMailer.deliver()

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
    {subject, body} = ChannelFormatter.format_payload(payload, :email)
    cc_emails = NotificationChannels.list_verified_emails(channel_id)

    result =
      new()
      |> to(channel.target)
      |> from(from_address())
      |> then(fn email -> Enum.reduce(cc_emails, email, &cc(&2, &1)) end)
      |> subject(subject)
      |> text_body(body)
      |> AlertMailer.deliver()

    {log_status, log_error} =
      case result do
        {:ok, _} -> {:success, nil}
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

    :ok
  end

  defp from_address, do: Application.fetch_env!(:holter, :email)[:from_address]
end
