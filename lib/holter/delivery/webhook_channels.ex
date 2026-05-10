defmodule Holter.Delivery.WebhookChannels do
  @moduledoc """
  Coordinator for the `webhook_channels` table.

  Public functions assume the caller has already stamped the tenant
  via one of the entry-point macros (`HolterWeb.LiveTenancy`,
  `HolterWeb.ApiTenancy`, or
  `Holter.Monitoring.Workers.WorkspaceScopedWorker`). The RLS policy
  `tenant_isolation` (keyed on `app.current_workspace_id`) reads the
  session var set by the boundary stamp.
  """

  import Ecto.Query

  alias Holter.Delivery.MonitorWebhookChannel
  alias Holter.Delivery.WebhookChannel
  alias Holter.Repo

  def list(workspace_id) do
    WebhookChannel
    |> where([w], w.workspace_id == ^workspace_id)
    |> order_by([w], asc: w.name)
    |> Repo.all()
  end

  def count(workspace_id) do
    WebhookChannel
    |> where([w], w.workspace_id == ^workspace_id)
    |> Repo.aggregate(:count)
  end

  def get(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %WebhookChannel{} = channel <- Repo.get(WebhookChannel, id) do
      {:ok, channel}
    else
      _ -> {:error, :not_found}
    end
  end

  def get!(id), do: Repo.get!(WebhookChannel, id)

  def create(attrs \\ %{}) do
    %WebhookChannel{}
    |> WebhookChannel.changeset(attrs)
    |> Repo.insert()
  end

  def update(%WebhookChannel{} = channel, attrs) do
    channel
    |> WebhookChannel.changeset(attrs)
    |> Repo.update()
  end

  def delete(%WebhookChannel{} = channel) do
    Repo.delete(channel)
  end

  def change(%WebhookChannel{} = channel, attrs \\ %{}),
    do: WebhookChannel.changeset(channel, attrs)

  @doc """
  Rotates the HMAC signing token. Returns `{:ok, channel}` with the
  fresh token in place.
  """
  def regenerate_signing_token(%WebhookChannel{} = channel) do
    channel
    |> Ecto.Changeset.change(signing_token: WebhookChannel.generate_signing_token())
    |> Repo.update()
  end

  @doc """
  Records the timestamp of the most recent test ping. Used by the
  cooldown gate in `Holter.Delivery.Engine`.
  """
  def touch_test_dispatched_at(%WebhookChannel{id: id}, %DateTime{} = now) do
    WebhookChannel
    |> where([w], w.id == ^id)
    |> Repo.update_all(set: [last_test_dispatched_at: now, updated_at: now])

    :ok
  end

  def link_monitor(monitor_id, webhook_channel_id) do
    %MonitorWebhookChannel{}
    |> MonitorWebhookChannel.changeset(%{
      monitor_id: monitor_id,
      webhook_channel_id: webhook_channel_id
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def unlink_monitor(monitor_id, webhook_channel_id) do
    MonitorWebhookChannel
    |> where(
      [l],
      l.monitor_id == ^monitor_id and l.webhook_channel_id == ^webhook_channel_id
    )
    |> Repo.delete_all()

    :ok
  end

  def list_for_monitor(monitor_id) do
    WebhookChannel
    |> join(:inner, [w], l in MonitorWebhookChannel,
      on:
        l.webhook_channel_id == w.id and l.monitor_id == ^monitor_id and
          l.is_active == true
    )
    |> Repo.all()
  end

  def list_monitor_ids_for(webhook_channel_id) do
    MonitorWebhookChannel
    |> where(
      [l],
      l.webhook_channel_id == ^webhook_channel_id and l.is_active == true
    )
    |> select([l], l.monitor_id)
    |> Repo.all()
  end

  def sync_monitors_for(webhook_channel_id, monitor_ids) do
    current_ids = list_monitor_ids_for(webhook_channel_id)

    Enum.each(monitor_ids -- current_ids, &link_monitor(&1, webhook_channel_id))
    Enum.each(current_ids -- monitor_ids, &unlink_monitor(&1, webhook_channel_id))

    :ok
  end
end
