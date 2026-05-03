defmodule HolterWeb.Api.EmailChannelJSON do
  @moduledoc """
  JSON view for the standalone email-channel resource (#29).

  Flat response shape — email fields live on the top-level object, no
  parent-channel wrapper. Recipients are not embedded here; they live on
  a sibling resource under `/email_channels/:id/recipients` once that
  endpoint is wired up.
  """
  alias Holter.Delivery.EmailChannel

  def index(%{channels: channels}) do
    %{data: Enum.map(channels, &data/1)}
  end

  def show(%{channel: channel}) do
    %{data: data(channel)}
  end

  defp data(%EmailChannel{} = channel) do
    %{
      id: channel.id,
      workspace_id: channel.workspace_id,
      name: channel.name,
      address: channel.address,
      settings: channel.settings,
      anti_phishing_code: channel.anti_phishing_code,
      verified_at: channel.verified_at,
      last_test_dispatched_at: channel.last_test_dispatched_at,
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end
end
