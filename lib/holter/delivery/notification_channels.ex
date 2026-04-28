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

  alias Holter.Delivery.Emails.{EmailChannelVerification, RecipientVerification}
  alias Holter.Mailers.InfoMailer
  alias Holter.Repo

  @subtypes [:webhook_channel, :email_channel]
  @full_preload [:webhook_channel, :email_channel, :recipients]

  def list_channels(workspace_id, filters \\ %{}) do
    NotificationChannel
    |> where([c], c.workspace_id == ^workspace_id)
    |> apply_type_filter(filters[:type])
    |> order_by([c], asc: c.name)
    |> preload(^@full_preload)
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
    |> Repo.preload(@full_preload)
    |> NotificationChannel.populate_virtuals()
  end

  def get_channel(id) do
    case Repo.get(NotificationChannel, id) do
      nil ->
        {:error, :not_found}

      channel ->
        {:ok,
         channel
         |> Repo.preload(@full_preload)
         |> NotificationChannel.populate_virtuals()}
    end
  end

  def create_channel(attrs \\ %{}) do
    %NotificationChannel{}
    |> NotificationChannel.changeset(attrs)
    |> Repo.insert()
    |> hydrate_after_write()
    |> maybe_inherit_workspace_verification()
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
  Records the timestamp of the most recent test ping for a channel,
  used by the cooldown gate in `Holter.Delivery.Engine.dispatch_test/1`.
  """
  def touch_test_dispatched_at(%NotificationChannel{id: id}, %DateTime{} = now) do
    NotificationChannel
    |> where([nc], nc.id == ^id)
    |> Repo.update_all(set: [last_test_dispatched_at: now, updated_at: now])

    :ok
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

  @doc """
  Generates a fresh verification token for an email channel and ships
  the verification email via InfoMailer. Returns
  `{:error, :not_an_email_channel}` for webhook channels.

  The verification URL points at the email-channel verify LiveView
  (`/delivery/notification-channels/email-channels/verify/:token`).
  """
  def send_email_channel_verification(%NotificationChannel{} = channel) do
    channel = Repo.preload(channel, @subtypes)

    case channel.email_channel do
      %EmailChannel{verified_at: %DateTime{}} -> {:ok, channel}
      %EmailChannel{} = ec -> rotate_and_deliver_verification(channel, ec)
      _ -> {:error, :not_an_email_channel}
    end
  end

  @doc """
  Verifies an email channel by its token. Sets `verified_at`, clears the
  token + expiry. Returns `{:ok, channel}` on success, `{:error,
  :expired}` for an expired link, `{:error, :not_found}` otherwise.
  """
  def verify_email_channel(token) do
    case get_email_channel_by_verification_token(token) do
      {:ok, ec} -> mark_email_channel_verified(ec)
      error -> error
    end
  end

  @doc """
  Reads an email channel by a still-valid verification token. Used
  primarily by `verify_email_channel/1`.
  """
  def get_email_channel_by_verification_token(token) when is_binary(token) do
    now = DateTime.utc_now()

    case Repo.get_by(EmailChannel, verification_token: token) do
      nil ->
        {:error, :not_found}

      %EmailChannel{verification_token_expires_at: nil} ->
        {:error, :not_found}

      %EmailChannel{verification_token_expires_at: expires_at} = ec ->
        if DateTime.compare(expires_at, now) == :gt,
          do: {:ok, ec},
          else: {:error, :expired}
    end
  end

  def get_email_channel_by_verification_token(_), do: {:error, :not_found}

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

  @doc """
  Rotates the verification token on a CC recipient and ships a fresh
  verification email. Returns `{:ok, recipient}` on success, `{:error,
  :not_found}` if the recipient no longer exists, `{:error,
  :already_verified}` if the recipient is already verified.
  """
  def resend_recipient_verification(recipient_id) do
    case Repo.get(NotificationChannelRecipient, recipient_id) do
      nil ->
        {:error, :not_found}

      %NotificationChannelRecipient{verified_at: %NaiveDateTime{}} ->
        {:error, :already_verified}

      %NotificationChannelRecipient{} = recipient ->
        rotate_and_deliver_recipient_verification(recipient)
    end
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

  defp rotate_and_deliver_verification(channel, %EmailChannel{} = ec) do
    token = EmailChannel.generate_verification_token()

    expires_at =
      DateTime.utc_now() |> DateTime.add(48 * 3600, :second) |> DateTime.truncate(:second)

    changeset =
      Ecto.Changeset.change(ec,
        verification_token: token,
        verification_token_expires_at: expires_at
      )

    with {:ok, _} <- Repo.update(changeset),
         {:ok, reloaded} <- reload_channel(channel) do
      verification_url = build_verification_url(token)

      reloaded
      |> EmailChannelVerification.build_verification_email(%{
        url: verification_url,
        from: info_from_address()
      })
      |> InfoMailer.deliver()

      {:ok, reloaded}
    end
  end

  defp mark_email_channel_verified(%EmailChannel{} = ec) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    parent = Repo.get!(NotificationChannel, ec.notification_channel_id)

    Repo.transaction(fn ->
      {:ok, updated_ec} =
        ec
        |> Ecto.Changeset.change(
          verified_at: now,
          verification_token: nil,
          verification_token_expires_at: nil
        )
        |> Repo.update()

      propagate_verification_to_siblings(parent.workspace_id, updated_ec, now)

      parent
      |> Repo.preload(@full_preload, force: true)
      |> NotificationChannel.populate_virtuals()
    end)
  end

  defp propagate_verification_to_siblings(workspace_id, %EmailChannel{} = source, now) do
    siblings =
      from(ec in EmailChannel,
        join: nc in NotificationChannel,
        on: ec.notification_channel_id == nc.id,
        where:
          nc.workspace_id == ^workspace_id and
            ec.address == ^source.address and
            ec.id != ^source.id and
            is_nil(ec.verified_at)
      )

    Repo.update_all(siblings, set: [verified_at: now, updated_at: now])
  end

  defp maybe_inherit_workspace_verification({:ok, %NotificationChannel{type: :email} = channel}) do
    case sibling_verified_at(channel) do
      nil ->
        {:ok, channel}

      %DateTime{} = verified_at ->
        channel.email_channel
        |> Ecto.Changeset.change(verified_at: verified_at)
        |> Repo.update()
        |> case do
          {:ok, _} -> reload_channel(channel)
          {:error, _} = error -> error
        end
    end
  end

  defp maybe_inherit_workspace_verification(other), do: other

  defp sibling_verified_at(%NotificationChannel{
         workspace_id: workspace_id,
         email_channel: %EmailChannel{address: address, id: ec_id}
       }) do
    from(ec in EmailChannel,
      join: nc in NotificationChannel,
      on: ec.notification_channel_id == nc.id,
      where:
        nc.workspace_id == ^workspace_id and
          ec.address == ^address and
          ec.id != ^ec_id and
          not is_nil(ec.verified_at),
      order_by: [desc: ec.verified_at],
      limit: 1,
      select: ec.verified_at
    )
    |> Repo.one()
  end

  defp build_verification_url(token) do
    HolterWeb.Endpoint.url() <> "/delivery/notification-channels/email-channels/verify/#{token}"
  end

  defp build_recipient_verification_url(token) do
    HolterWeb.Endpoint.url() <> "/delivery/notification-channels/recipients/verify/#{token}"
  end

  defp info_from_address, do: Application.fetch_env!(:holter, :info_email)[:from_address]

  defp rotate_and_deliver_recipient_verification(%NotificationChannelRecipient{} = recipient) do
    new_token = NotificationChannelRecipient.generate_token()

    new_expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(48 * 3600, :second)
      |> NaiveDateTime.truncate(:second)

    changeset =
      NotificationChannelRecipient.changeset(recipient, %{
        token: new_token,
        token_expires_at: new_expires_at
      })

    with {:ok, updated} <- Repo.update(changeset) do
      channel = get_channel!(updated.notification_channel_id)
      verification_url = build_recipient_verification_url(new_token)

      RecipientVerification.build_verification_email(
        updated,
        channel,
        %{url: verification_url, from: info_from_address()}
      )
      |> InfoMailer.deliver()

      {:ok, updated}
    end
  end

  defp reload_channel(channel) do
    {:ok,
     channel
     |> Repo.preload(@full_preload, force: true)
     |> NotificationChannel.populate_virtuals()}
  end

  defp hydrate_after_write({:ok, channel}) do
    {:ok,
     channel
     |> Repo.preload(@full_preload, force: true)
     |> NotificationChannel.populate_virtuals()}
  end

  defp hydrate_after_write({:error, _} = error), do: error
end
