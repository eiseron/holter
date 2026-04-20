defmodule Holter.Delivery.NotificationChannels do
  @moduledoc false

  import Ecto.Query

  alias Holter.Delivery.{MonitorNotification, NotificationChannel}
  alias Holter.Repo

  def list_channels(workspace_id) do
    NotificationChannel
    |> where([c], c.workspace_id == ^workspace_id)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def count_channels(workspace_id) do
    NotificationChannel
    |> where([c], c.workspace_id == ^workspace_id)
    |> Repo.aggregate(:count)
  end

  def get_channel!(id), do: Repo.get!(NotificationChannel, id)

  def get_channel(id) do
    case Repo.get(NotificationChannel, id) do
      nil -> {:error, :not_found}
      channel -> {:ok, channel}
    end
  end

  def create_channel(attrs \\ %{}) do
    %NotificationChannel{}
    |> NotificationChannel.changeset(attrs)
    |> Repo.insert()
  end

  def update_channel(%NotificationChannel{} = channel, attrs) do
    channel
    |> NotificationChannel.changeset(attrs)
    |> Repo.update()
  end

  def delete_channel(%NotificationChannel{} = channel) do
    Repo.delete(channel)
  end

  def change_channel(%NotificationChannel{} = channel, attrs \\ %{}) do
    NotificationChannel.changeset(channel, attrs)
  end

  def link_monitor(monitor_id, channel_id) do
    %MonitorNotification{}
    |> MonitorNotification.changeset(%{
      monitor_id: monitor_id,
      notification_channel_id: channel_id
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def unlink_monitor(monitor_id, channel_id) do
    MonitorNotification
    |> where([mn], mn.monitor_id == ^monitor_id and mn.notification_channel_id == ^channel_id)
    |> Repo.delete_all()

    :ok
  end

  def list_channels_for_monitor(monitor_id) do
    NotificationChannel
    |> join(:inner, [c], mn in MonitorNotification,
      on:
        mn.notification_channel_id == c.id and mn.monitor_id == ^monitor_id and
          mn.is_active == true
    )
    |> Repo.all()
  end

  def list_monitor_ids_for_channel(channel_id) do
    MonitorNotification
    |> where([mn], mn.notification_channel_id == ^channel_id and mn.is_active == true)
    |> select([mn], mn.monitor_id)
    |> Repo.all()
  end

  def sync_monitors_for_channel(channel_id, monitor_ids) do
    current_ids = list_monitor_ids_for_channel(channel_id)

    Enum.each(monitor_ids -- current_ids, &link_monitor(&1, channel_id))
    Enum.each(current_ids -- monitor_ids, &unlink_monitor(&1, channel_id))

    :ok
  end
end
