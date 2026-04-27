defmodule Holter.Delivery.NotificationChannels do
  @moduledoc false

  import Ecto.Query

  alias Holter.Delivery.{
    EmailChannel,
    MonitorNotification,
    NotificationChannel,
    NotificationChannelRecipient,
    WebhookChannel
  }

  alias Holter.Repo

  @subtypes [:webhook_channel, :email_channel]

  def list_channels(workspace_id, filters \\ %{}) do
    NotificationChannel
    |> where([c], c.workspace_id == ^workspace_id)
    |> apply_type_filter(filters[:type])
    |> order_by([c], asc: c.name)
    |> preload(^@subtypes)
    |> Repo.all()
    |> Enum.map(&NotificationChannel.populate_virtuals/1)
  end

  def count_channels(workspace_id) do
    NotificationChannel
    |> where([c], c.workspace_id == ^workspace_id)
    |> Repo.aggregate(:count)
  end

  def get_channel!(id) do
    NotificationChannel
    |> Repo.get!(id)
    |> Repo.preload(@subtypes)
    |> NotificationChannel.populate_virtuals()
  end

  def get_channel(id) do
    case Repo.get(NotificationChannel, id) do
      nil ->
        {:error, :not_found}

      channel ->
        {:ok,
         channel
         |> Repo.preload(@subtypes)
         |> NotificationChannel.populate_virtuals()}
    end
  end

  def create_channel(attrs \\ %{}) do
    %NotificationChannel{}
    |> NotificationChannel.changeset(attrs)
    |> Repo.insert()
    |> hydrate_after_write()
  end

  def update_channel(%NotificationChannel{} = channel, attrs) do
    channel
    |> Repo.preload(@subtypes)
    |> NotificationChannel.changeset(attrs)
    |> Repo.update()
    |> hydrate_after_write()
  end

  def delete_channel(%NotificationChannel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Rotates a webhook channel's HMAC signing token. Returns
  `{:error, :not_a_webhook_channel}` for email channels.
  """
  def regenerate_signing_token(%NotificationChannel{} = channel) do
    channel = Repo.preload(channel, @subtypes)

    case channel.webhook_channel do
      %WebhookChannel{} = wc -> rotate_webhook_signing_token(channel, wc)
      _ -> {:error, :not_a_webhook_channel}
    end
  end

  @doc """
  Rotates an email channel's anti-phishing code. Returns
  `{:error, :not_an_email_channel}` for webhook channels.
  """
  def regenerate_anti_phishing_code(%NotificationChannel{} = channel) do
    channel = Repo.preload(channel, @subtypes)

    case channel.email_channel do
      %EmailChannel{} = ec -> rotate_email_anti_phishing_code(channel, ec)
      _ -> {:error, :not_an_email_channel}
    end
  end

  def change_channel(%NotificationChannel{} = channel, attrs \\ %{}) do
    channel
    |> Repo.preload(@subtypes)
    |> NotificationChannel.changeset(attrs)
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
    |> preload(^@subtypes)
    |> Repo.all()
    |> Enum.map(&NotificationChannel.populate_virtuals/1)
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

  defp apply_type_filter(query, :webhook),
    do: join(query, :inner, [c], assoc(c, :webhook_channel))

  defp apply_type_filter(query, :email),
    do: join(query, :inner, [c], assoc(c, :email_channel))

  defp apply_type_filter(query, _), do: query

  defp rotate_webhook_signing_token(channel, %WebhookChannel{} = wc) do
    new_token = WebhookChannel.generate_signing_token()
    changeset = Ecto.Changeset.change(wc, signing_token: new_token)

    case Repo.update(changeset) do
      {:ok, _} -> reload_channel(channel)
      {:error, _} = error -> error
    end
  end

  defp rotate_email_anti_phishing_code(channel, %EmailChannel{} = ec) do
    new_code = EmailChannel.generate_anti_phishing_code()
    changeset = Ecto.Changeset.change(ec, anti_phishing_code: new_code)

    case Repo.update(changeset) do
      {:ok, _} -> reload_channel(channel)
      {:error, _} = error -> error
    end
  end

  defp reload_channel(channel) do
    {:ok,
     channel
     |> Repo.preload(@subtypes, force: true)
     |> NotificationChannel.populate_virtuals()}
  end

  defp hydrate_after_write({:ok, channel}) do
    {:ok,
     channel
     |> Repo.preload(@subtypes, force: true)
     |> NotificationChannel.populate_virtuals()}
  end

  defp hydrate_after_write({:error, _} = error), do: error
end
