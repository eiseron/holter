defmodule Holter.Delivery.NotificationChannels do
  @moduledoc false

  import Ecto.Query

  alias Holter.Delivery.{MonitorNotification, NotificationChannel, NotificationChannelRecipient}
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

  def list_recipients(channel_id) do
    NotificationChannelRecipient
    |> where([r], r.notification_channel_id == ^channel_id)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  def add_recipient(channel_id, email) do
    token = NotificationChannelRecipient.generate_token()
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), 48 * 3600, :second)

    %NotificationChannelRecipient{}
    |> NotificationChannelRecipient.changeset(%{
      notification_channel_id: channel_id,
      email: email,
      token: token,
      token_expires_at: NaiveDateTime.truncate(expires_at, :second)
    })
    |> Repo.insert()
  end

  def remove_recipient(recipient_id) do
    NotificationChannelRecipient
    |> where([r], r.id == ^recipient_id)
    |> Repo.delete_all()

    :ok
  end

  def get_recipient_by_token(token) do
    now = NaiveDateTime.utc_now()

    case Repo.get_by(NotificationChannelRecipient, token: token) do
      nil ->
        {:error, :not_found}

      recipient ->
        if NaiveDateTime.compare(recipient.token_expires_at, now) == :gt do
          {:ok, recipient}
        else
          {:error, :expired}
        end
    end
  end

  def verify_recipient(token) do
    case get_recipient_by_token(token) do
      {:ok, recipient} ->
        recipient
        |> NotificationChannelRecipient.changeset(%{
          verified_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
          token: nil,
          token_expires_at: nil
        })
        |> Repo.update()

      error ->
        error
    end
  end

  def list_verified_emails(channel_id) do
    NotificationChannelRecipient
    |> where([r], r.notification_channel_id == ^channel_id and not is_nil(r.verified_at))
    |> select([r], r.email)
    |> Repo.all()
  end
end
