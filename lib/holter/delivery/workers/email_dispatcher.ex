defmodule Holter.Delivery.Workers.EmailDispatcher do
  @moduledoc false

  use Oban.Worker, queue: :notifications, max_attempts: 20

  import Swoosh.Email

  alias Holter.Delivery.{EmailChannel, EmailChannels}
  alias Holter.Delivery.Engine.{ChannelFormatter, PayloadBuilder}
  alias Holter.Mailers.AlertMailer
  alias Holter.Monitoring

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "email_channel_id" => channel_id,
          "monitor_id" => monitor_id,
          "incident_id" => incident_id,
          "event" => event
        }
      }) do
    channel = EmailChannels.get!(channel_id)
    monitor = Monitoring.get_monitor!(monitor_id)
    incident = Monitoring.get_incident!(incident_id)
    now = DateTime.utc_now()

    payload =
      PayloadBuilder.build_incident_payload(monitor, incident, %{
        event: String.to_existing_atom(event),
        now: now
      })

    {subject, body} = ChannelFormatter.format_payload(payload, :email)
    body = ChannelFormatter.append_anti_phishing_footer(body, channel)

    deliver(channel, subject, body)
  end

  def perform(%Oban.Job{args: %{"email_channel_id" => channel_id, "test" => true}}) do
    channel = EmailChannels.get!(channel_id)
    now = DateTime.utc_now()

    payload = PayloadBuilder.build_test_payload(channel, :email, now)
    {subject, body} = ChannelFormatter.format_payload(payload, :email)
    body = ChannelFormatter.append_anti_phishing_footer(body, channel)

    deliver(channel, subject, body)
  end

  defp deliver(channel, subject, body) do
    case compute_recipients(channel) do
      {nil, []} ->
        {:cancel, :no_verified_recipients}

      {nil, [primary | cc]} ->
        send_email({primary, cc}, %{subject: subject, body: body})

      {primary, cc} ->
        send_email({primary, cc}, %{subject: subject, body: body})
    end
  end

  defp send_email({primary, cc}, %{subject: subject, body: body}) do
    new()
    |> to(primary)
    |> from(from_address())
    |> then(fn email -> Enum.reduce(cc, email, &cc(&2, &1)) end)
    |> subject(subject)
    |> text_body(body)
    |> AlertMailer.deliver()

    :ok
  end

  defp compute_recipients(%EmailChannel{} = channel) do
    primary =
      if EmailChannel.verified?(channel), do: channel.address, else: nil

    {primary, EmailChannels.list_verified_emails(channel.id)}
  end

  defp from_address, do: Application.fetch_env!(:holter, :email)[:from_address]
end
