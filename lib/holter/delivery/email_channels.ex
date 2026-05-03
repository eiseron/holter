defmodule Holter.Delivery.EmailChannels do
  @moduledoc """
  Context for the standalone email-channel entity introduced by #29.

  Operates directly on the `email_channels` table. Verification — both the
  per-channel address verification and propagation across same-address siblings
  in a workspace — lives here, against the standalone columns. The legacy
  parent path is unaffected and continues to coexist until the parent table is
  dropped.
  """

  import Ecto.Query

  alias Holter.Delivery.EmailChannel
  alias Holter.Delivery.EmailChannelRecipient
  alias Holter.Delivery.Emails.{EmailChannelVerification, RecipientVerification}
  alias Holter.Delivery.MonitorEmailChannel
  alias Holter.Mailers.InfoMailer
  alias Holter.Repo

  def list(workspace_id) do
    EmailChannel
    |> where([e], e.workspace_id == ^workspace_id)
    |> order_by([e], asc: e.name)
    |> Repo.all()
  end

  def count(workspace_id) do
    EmailChannel
    |> where([e], e.workspace_id == ^workspace_id)
    |> Repo.aggregate(:count)
  end

  def get(id) do
    case Repo.get(EmailChannel, id) do
      nil -> {:error, :not_found}
      channel -> {:ok, channel}
    end
  end

  def get!(id), do: Repo.get!(EmailChannel, id)

  def create(attrs \\ %{}) do
    %EmailChannel{}
    |> EmailChannel.changeset(attrs)
    |> Repo.insert()
    |> maybe_inherit_workspace_verification()
  end

  def update(%EmailChannel{} = channel, attrs) do
    channel
    |> EmailChannel.changeset(attrs)
    |> Repo.update()
  end

  def delete(%EmailChannel{} = channel), do: Repo.delete(channel)

  def change(%EmailChannel{} = channel, attrs \\ %{}),
    do: EmailChannel.changeset(channel, attrs)

  def regenerate_anti_phishing_code(%EmailChannel{} = channel) do
    channel
    |> Ecto.Changeset.change(anti_phishing_code: EmailChannel.generate_anti_phishing_code())
    |> Repo.update()
  end

  def touch_test_dispatched_at(%EmailChannel{id: id}, %DateTime{} = now) do
    EmailChannel
    |> where([e], e.id == ^id)
    |> Repo.update_all(set: [last_test_dispatched_at: now, updated_at: now])

    :ok
  end

  def link_monitor(monitor_id, email_channel_id) do
    %MonitorEmailChannel{}
    |> MonitorEmailChannel.changeset(%{
      monitor_id: monitor_id,
      email_channel_id: email_channel_id
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def unlink_monitor(monitor_id, email_channel_id) do
    MonitorEmailChannel
    |> where(
      [l],
      l.monitor_id == ^monitor_id and l.email_channel_id == ^email_channel_id
    )
    |> Repo.delete_all()

    :ok
  end

  def list_for_monitor(monitor_id) do
    EmailChannel
    |> join(:inner, [e], l in MonitorEmailChannel,
      on:
        l.email_channel_id == e.id and l.monitor_id == ^monitor_id and
          l.is_active == true
    )
    |> Repo.all()
  end

  def list_monitor_ids_for(email_channel_id) do
    MonitorEmailChannel
    |> where(
      [l],
      l.email_channel_id == ^email_channel_id and l.is_active == true
    )
    |> select([l], l.monitor_id)
    |> Repo.all()
  end

  def sync_monitors_for(email_channel_id, monitor_ids) do
    current_ids = list_monitor_ids_for(email_channel_id)

    Enum.each(monitor_ids -- current_ids, &link_monitor(&1, email_channel_id))
    Enum.each(current_ids -- monitor_ids, &unlink_monitor(&1, email_channel_id))

    :ok
  end

  def list_recipients(email_channel_id) do
    EmailChannelRecipient
    |> where([r], r.email_channel_id == ^email_channel_id)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  def list_verified_emails(email_channel_id) do
    EmailChannelRecipient
    |> where([r], r.email_channel_id == ^email_channel_id and not is_nil(r.verified_at))
    |> select([r], r.email)
    |> Repo.all()
  end

  def add_recipient(email_channel_id, email) do
    token = EmailChannelRecipient.generate_token()
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), 48 * 3600, :second)

    %EmailChannelRecipient{}
    |> EmailChannelRecipient.changeset(%{
      email_channel_id: email_channel_id,
      email: email,
      token: token,
      token_expires_at: NaiveDateTime.truncate(expires_at, :second)
    })
    |> Repo.insert()
  end

  def remove_recipient(recipient_id) do
    EmailChannelRecipient
    |> where([r], r.id == ^recipient_id)
    |> Repo.delete_all()

    :ok
  end

  def resend_recipient_verification(recipient_id) do
    case Repo.get(EmailChannelRecipient, recipient_id) do
      nil ->
        {:error, :not_found}

      %EmailChannelRecipient{verified_at: %NaiveDateTime{}} ->
        {:error, :already_verified}

      %EmailChannelRecipient{} = recipient ->
        rotate_and_deliver_recipient_verification(recipient)
    end
  end

  def get_recipient_by_token(token) do
    now = NaiveDateTime.utc_now()

    case Repo.get_by(EmailChannelRecipient, token: token) do
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
        |> EmailChannelRecipient.changeset(%{
          verified_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
          token: nil,
          token_expires_at: nil
        })
        |> Repo.update()

      error ->
        error
    end
  end

  @doc """
  Generates a fresh verification token for an email channel and sends
  the verification email. Already-verified channels short-circuit to
  `{:ok, channel}` without rotating the token.
  """
  def send_verification(%EmailChannel{verified_at: %DateTime{}} = channel), do: {:ok, channel}

  def send_verification(%EmailChannel{} = channel) do
    token = EmailChannel.generate_verification_token()

    expires_at =
      DateTime.utc_now() |> DateTime.add(48 * 3600, :second) |> DateTime.truncate(:second)

    changeset =
      Ecto.Changeset.change(channel,
        verification_token: token,
        verification_token_expires_at: expires_at
      )

    with {:ok, updated} <- Repo.update(changeset) do
      verification_url = build_verification_url(token)

      updated
      |> EmailChannelVerification.build_verification_email(%{
        url: verification_url,
        from: info_from_address()
      })
      |> InfoMailer.deliver()

      {:ok, updated}
    end
  end

  @doc """
  Verifies an email channel by its token. Sets `verified_at`, clears the
  token, and propagates verification to same-address siblings in the
  workspace.
  """
  def verify(token) do
    case get_by_verification_token(token) do
      {:ok, channel} -> mark_verified_propagating(channel)
      error -> error
    end
  end

  def get_by_verification_token(token) when is_binary(token) do
    now = DateTime.utc_now()

    case Repo.get_by(EmailChannel, verification_token: token) do
      nil ->
        {:error, :not_found}

      %EmailChannel{verification_token_expires_at: nil} ->
        {:error, :not_found}

      %EmailChannel{verification_token_expires_at: expires_at} = channel ->
        if DateTime.compare(expires_at, now) == :gt,
          do: {:ok, channel},
          else: {:error, :expired}
    end
  end

  def get_by_verification_token(_), do: {:error, :not_found}

  defp mark_verified_propagating(%EmailChannel{} = channel) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      {:ok, updated} =
        channel
        |> Ecto.Changeset.change(
          verified_at: now,
          verification_token: nil,
          verification_token_expires_at: nil
        )
        |> Repo.update()

      propagate_verification_to_siblings(updated, now)

      updated
    end)
  end

  defp propagate_verification_to_siblings(%EmailChannel{} = source, now) do
    siblings =
      from(e in EmailChannel,
        where:
          e.workspace_id == ^source.workspace_id and
            e.address == ^source.address and
            e.id != ^source.id and
            is_nil(e.verified_at)
      )

    Repo.update_all(siblings, set: [verified_at: now, updated_at: now])
  end

  defp maybe_inherit_workspace_verification({:ok, %EmailChannel{verified_at: nil} = channel}) do
    case sibling_verified_at(channel) do
      nil ->
        {:ok, channel}

      %DateTime{} = verified_at ->
        channel
        |> Ecto.Changeset.change(verified_at: verified_at)
        |> Repo.update()
    end
  end

  defp maybe_inherit_workspace_verification(other), do: other

  defp sibling_verified_at(%EmailChannel{
         workspace_id: workspace_id,
         address: address,
         id: id
       }) do
    from(e in EmailChannel,
      where:
        e.workspace_id == ^workspace_id and
          e.address == ^address and
          e.id != ^id and
          not is_nil(e.verified_at),
      order_by: [desc: e.verified_at],
      limit: 1,
      select: e.verified_at
    )
    |> Repo.one()
  end

  defp build_verification_url(token) do
    HolterWeb.Endpoint.url() <> "/delivery/email-channels/verify/#{token}"
  end

  defp build_recipient_verification_url(token) do
    HolterWeb.Endpoint.url() <> "/delivery/email-channels/recipients/verify/#{token}"
  end

  defp info_from_address, do: Application.fetch_env!(:holter, :info_email)[:from_address]

  defp rotate_and_deliver_recipient_verification(%EmailChannelRecipient{} = recipient) do
    new_token = EmailChannelRecipient.generate_token()

    new_expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(48 * 3600, :second)
      |> NaiveDateTime.truncate(:second)

    changeset =
      EmailChannelRecipient.changeset(recipient, %{
        token: new_token,
        token_expires_at: new_expires_at
      })

    with {:ok, updated} <- Repo.update(changeset) do
      channel = get!(updated.email_channel_id)
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
end
