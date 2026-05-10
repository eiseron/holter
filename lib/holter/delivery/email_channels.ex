defmodule Holter.Delivery.EmailChannels do
  @moduledoc """
  Coordinator for the `email_channels` table. The channel itself is a
  named bucket of recipients — every verified address that should
  receive alerts lives in `email_channel_recipients`. Per-recipient
  verification (and the resend flow) lives here, against that table.

  Public functions assume the caller has already stamped the tenant
  via one of the entry-point macros (`HolterWeb.LiveTenancy`,
  `HolterWeb.ApiTenancy`, or
  `Holter.Monitoring.Workers.WorkspaceScopedWorker`). RLS policies on
  `email_channels` (workspace-keyed direct) and
  `email_channel_recipients` / `monitor_email_channels` (anchored on
  `email_channels.workspace_id`) read `app.current_workspace_id` set
  by the boundary stamp.

  Public recipient-verification URLs include the workspace slug
  (`/delivery/workspaces/:slug/email-channels/recipients/verify/:token`)
  so the anonymous verify LiveView can resolve the workspace from the
  URL and stamp the tenant before reading the recipient by token —
  RLS does not have a non-tenant path for these reads.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Holter.Delivery.EmailChannel
  alias Holter.Delivery.EmailChannelRecipient
  alias Holter.Delivery.Emails.RecipientVerification
  alias Holter.Delivery.MonitorEmailChannel
  alias Holter.Mailers.InfoMailer
  alias Holter.Monitoring
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
    with {:ok, _} <- Ecto.UUID.cast(id),
         %EmailChannel{} = channel <- Repo.get(EmailChannel, id) do
      {:ok, channel}
    else
      _ -> {:error, :not_found}
    end
  end

  def get!(id), do: Repo.get!(EmailChannel, id)

  def create(attrs \\ %{}) do
    %EmailChannel{}
    |> EmailChannel.changeset(attrs)
    |> Repo.insert()
  end

  def update(%EmailChannel{} = channel, attrs) do
    channel
    |> EmailChannel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Applies a batch of changes (channel attrs + recipient additions + recipient
  removals) atomically. `staged` carries `:attrs`, `:additions`, and `:removed_ids`.
  Returns `{:ok, %{channel: channel, added: [recipient]}}` on success — caller
  is expected to dispatch verification emails for each added recipient. On
  failure rolls back the whole transaction so partial state never lands in the
  database.
  """
  def apply_staged_changes(%EmailChannel{} = channel, %{} = staged) do
    %{attrs: attrs, additions: additions, removed_ids: removed_ids} = staged

    Multi.new()
    |> Multi.update(:channel, EmailChannel.changeset(channel, attrs))
    |> Multi.run(:remove, fn repo, _changes ->
      remove_recipients(repo, channel.id, removed_ids)
    end)
    |> Multi.run(:added, fn repo, _changes ->
      insert_recipients(repo, channel.id, additions)
    end)
    |> Repo.transaction()
    |> finalize_staged_changes()
  end

  def delete(%EmailChannel{} = channel) do
    Repo.delete(channel)
  end

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

  defp workspace_slug_for(workspace_id) do
    Monitoring.get_workspace!(workspace_id).slug
  end

  defp build_recipient_verification_url(workspace_slug, token) do
    HolterWeb.Endpoint.url() <>
      "/delivery/workspaces/#{workspace_slug}/email-channels/recipients/verify/#{token}"
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
      workspace_slug = workspace_slug_for(channel.workspace_id)
      verification_url = build_recipient_verification_url(workspace_slug, new_token)

      RecipientVerification.build_verification_email(
        updated,
        channel,
        %{url: verification_url, from: info_from_address()}
      )
      |> InfoMailer.deliver()

      {:ok, updated}
    end
  end

  defp remove_recipients(repo, channel_id, removed_ids) do
    {n, _} =
      repo.delete_all(
        from(r in EmailChannelRecipient,
          where: r.id in ^removed_ids and r.email_channel_id == ^channel_id
        )
      )

    {:ok, n}
  end

  defp insert_recipients(repo, channel_id, addition_emails) do
    expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(48 * 3600, :second)
      |> NaiveDateTime.truncate(:second)

    Enum.reduce_while(addition_emails, {:ok, []}, fn email, {:ok, acc} ->
      attrs = %{
        email_channel_id: channel_id,
        email: email,
        token: EmailChannelRecipient.generate_token(),
        token_expires_at: expires_at
      }

      case repo.insert(EmailChannelRecipient.changeset(%EmailChannelRecipient{}, attrs)) do
        {:ok, recipient} -> {:cont, {:ok, [recipient | acc]}}
        {:error, cs} -> {:halt, {:error, cs}}
      end
    end)
  end

  defp finalize_staged_changes({:ok, %{channel: channel, added: added}}),
    do: {:ok, %{channel: channel, added: Enum.reverse(added)}}

  defp finalize_staged_changes({:error, _step, reason, _changes}), do: {:error, reason}
end
