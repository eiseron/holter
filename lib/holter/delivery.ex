defmodule Holter.Delivery do
  @moduledoc """
  Top-level Delivery facade. Mostly empty after #29 — channel-specific work
  lives in `Holter.Delivery.WebhookChannels` and `Holter.Delivery.EmailChannels`.
  This module only exposes operations that span both subtypes.
  """

  alias Holter.Delivery.{ChannelLogs, EmailChannels, WebhookChannels}

  @doc """
  Total channel count across both subtypes for a workspace.
  Used by the sidebar; per-type counts go through their own contexts.
  """
  def count_channels(workspace_id) do
    WebhookChannels.count(workspace_id) + EmailChannels.count(workspace_id)
  end

  defdelegate list_channel_logs(channel, filters), to: ChannelLogs
end
