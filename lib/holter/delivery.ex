defmodule Holter.Delivery do
  @moduledoc """
  The Delivery context — manages notification channels and dispatches alerts.
  """

  alias Holter.Delivery.NotificationChannels

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
end
