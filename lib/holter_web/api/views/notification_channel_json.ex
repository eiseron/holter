defmodule HolterWeb.Api.NotificationChannelJSON do
  @moduledoc """
  JSON view for rendering notification channel data.

  Response shape mirrors the storage layout: a parent
  `notification_channel` carrying common fields plus exactly one of
  `webhook_channel` / `email_channel` populated with the type-specific
  data. The unused subtype is rendered as `null`.
  """
  alias Holter.Delivery.{
    EmailChannel,
    NotificationChannel,
    NotificationChannelRecipient,
    WebhookChannel
  }

  def index(%{channels: channels}) do
    %{data: for(channel <- channels, do: data(channel))}
  end

  def show(%{channel: channel}) do
    %{data: data(channel)}
  end

  defp data(%NotificationChannel{} = channel) do
    %{
      id: channel.id,
      workspace_id: channel.workspace_id,
      name: channel.name,
      type: NotificationChannel.type(channel),
      webhook_channel: webhook_data(channel.webhook_channel),
      email_channel: email_data(channel),
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end

  defp webhook_data(%WebhookChannel{} = wc) do
    %{
      url: wc.url,
      settings: wc.settings,
      signing_token: wc.signing_token
    }
  end

  defp webhook_data(_), do: nil

  defp email_data(%NotificationChannel{
         email_channel: %EmailChannel{} = ec,
         recipients: recipients
       }) do
    %{
      address: ec.address,
      settings: ec.settings,
      anti_phishing_code: ec.anti_phishing_code,
      verified_at: ec.verified_at,
      recipients: recipient_list(recipients)
    }
  end

  defp email_data(_), do: nil

  defp recipient_list(recipients) when is_list(recipients) do
    Enum.map(recipients, fn %NotificationChannelRecipient{} = r ->
      %{id: r.id, email: r.email, verified_at: format_naive_as_utc(r.verified_at)}
    end)
  end

  defp recipient_list(_), do: []

  defp format_naive_as_utc(nil), do: nil

  defp format_naive_as_utc(%NaiveDateTime{} = ndt) do
    ndt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()
  end
end
