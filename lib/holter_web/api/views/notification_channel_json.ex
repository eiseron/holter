defmodule HolterWeb.Api.NotificationChannelJSON do
  @moduledoc """
  JSON view for rendering notification channel data.
  """
  alias Holter.Delivery.NotificationChannel

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
      type: channel.type,
      target: channel.target,
      settings: channel.settings,
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end
end
