defmodule HolterWeb.Api.WebhookChannelJSON do
  @moduledoc """
  JSON view for the standalone webhook-channel resource (#29).

  Flat response shape — webhook fields live on the top-level object,
  no parent-channel wrapper.
  """
  alias Holter.Delivery.WebhookChannel

  def index(%{channels: channels}) do
    %{data: Enum.map(channels, &data/1)}
  end

  def show(%{channel: channel}) do
    %{data: data(channel)}
  end

  defp data(%WebhookChannel{} = channel) do
    %{
      id: channel.id,
      workspace_id: channel.workspace_id,
      name: channel.name,
      url: channel.url,
      settings: channel.settings,
      signing_token: channel.signing_token,
      last_test_dispatched_at: channel.last_test_dispatched_at,
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end
end
