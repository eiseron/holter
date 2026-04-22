defmodule Holter.Delivery do
  @moduledoc """
  The Delivery context — manages notification channels and dispatches alerts.
  """

  alias Holter.Delivery.{ChannelLogs, NotificationChannels}

  defdelegate list_channels(workspace_id), to: NotificationChannels
  defdelegate count_channels(workspace_id), to: NotificationChannels
  defdelegate get_channel!(id), to: NotificationChannels
  defdelegate get_channel(id), to: NotificationChannels
  defdelegate create_channel(attrs), to: NotificationChannels
  defdelegate update_channel(channel, attrs), to: NotificationChannels
  defdelegate delete_channel(channel), to: NotificationChannels
  defdelegate change_channel(channel, attrs \\ %{}), to: NotificationChannels
  defdelegate link_monitor(monitor_id, channel_id), to: NotificationChannels
  defdelegate unlink_monitor(monitor_id, channel_id), to: NotificationChannels
  defdelegate list_channels_for_monitor(monitor_id), to: NotificationChannels
  defdelegate list_monitor_ids_for_channel(channel_id), to: NotificationChannels
  defdelegate sync_monitors_for_channel(channel_id, monitor_ids), to: NotificationChannels
  defdelegate list_recipients(channel_id), to: NotificationChannels
  defdelegate add_recipient(channel_id, email), to: NotificationChannels
  defdelegate remove_recipient(recipient_id), to: NotificationChannels
  defdelegate get_recipient_by_token(token), to: NotificationChannels
  defdelegate verify_recipient(token), to: NotificationChannels
  defdelegate list_verified_emails(channel_id), to: NotificationChannels

  defdelegate list_channel_logs(channel, filters), to: ChannelLogs
  defdelegate get_channel_log!(id), to: ChannelLogs
end
