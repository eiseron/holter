defmodule HolterWeb.Api.NotificationChannelJSON do
  @moduledoc """
  JSON view for rendering notification channel data.

  Response shape mirrors the storage layout: a parent
  `notification_channel` carrying common fields plus exactly one of
  `webhook_channel` / `email_channel` populated with the type-specific
  data. The unused subtype is rendered as `null`.
  """
  alias Holter.Delivery.{EmailChannel, NotificationChannel, WebhookChannel}

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
      email_channel: email_data(channel.email_channel),
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

  defp email_data(%EmailChannel{} = ec) do
    %{
      address: ec.address,
      settings: ec.settings,
      anti_phishing_code: ec.anti_phishing_code
    }
  end

  defp email_data(_), do: nil
end
