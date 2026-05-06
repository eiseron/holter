defmodule Holter.Delivery.WebhookChannels do
  @moduledoc """
  Coordinator for the `webhook_channels` table. Every public function
  whose DB work is keyed on a workspace wraps in
  `Holter.Repo.Tenant.with_workspace!/2`, so the RLS policy
  `tenant_isolation` (keyed on `app.current_workspace_id`) sees the
  correct tenant under the `holter_app` role at runtime.

  By-id fetchers (`get/1`, `get!/1`) and join-table helpers that take
  only a `monitor_id` (`list_for_monitor/1`, `link_monitor/2`,
  `unlink_monitor/2`, `list_monitor_ids_for/1`, `sync_monitors_for/2`)
  are NOT wrapped — the caller (controller, LiveView, worker) is
  expected to have set the tenant before calling.
  """

  import Ecto.Query

  alias Holter.Delivery.MonitorWebhookChannel
  alias Holter.Delivery.WebhookChannel
  alias Holter.Identity.Tenant, as: IdentityTenant
  alias Holter.Repo
  alias Holter.Repo.Tenant

  def list(workspace_id) do
    Tenant.with_workspace!(workspace_id, fn ->
      WebhookChannel
      |> where([w], w.workspace_id == ^workspace_id)
      |> order_by([w], asc: w.name)
      |> Repo.all()
    end)
  end

  def count(workspace_id) do
    Tenant.with_workspace!(workspace_id, fn ->
      WebhookChannel
      |> where([w], w.workspace_id == ^workspace_id)
      |> Repo.aggregate(:count)
    end)
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
    workspace_id = attrs[:workspace_id] || attrs["workspace_id"]

    case IdentityTenant.parse_workspace_id(workspace_id) do
      {:ok, _} ->
        Tenant.with_workspace!(workspace_id, fn ->
          %WebhookChannel{}
          |> WebhookChannel.changeset(attrs)
          |> Repo.insert()
        end)

      {:error, _} ->
        %WebhookChannel{}
        |> WebhookChannel.changeset(attrs)
        |> Repo.insert()
    end
  end

  def update(%WebhookChannel{} = channel, attrs) do
    Tenant.with_workspace!(channel.workspace_id, fn ->
      channel
      |> WebhookChannel.changeset(attrs)
      |> Repo.update()
    end)
  end

  def delete(%WebhookChannel{} = channel) do
    Tenant.with_workspace!(channel.workspace_id, fn -> Repo.delete(channel) end)
  end

  def change(%WebhookChannel{} = channel, attrs \\ %{}),
    do: WebhookChannel.changeset(channel, attrs)

  @doc """
  Rotates the HMAC signing token. Returns `{:ok, channel}` with the
  fresh token in place.
  """
  def regenerate_signing_token(%WebhookChannel{} = channel) do
    Tenant.with_workspace!(channel.workspace_id, fn ->
      channel
      |> Ecto.Changeset.change(signing_token: WebhookChannel.generate_signing_token())
      |> Repo.update()
    end)
  end

  @doc """
  Records the timestamp of the most recent test ping. Used by the
  cooldown gate in `Holter.Delivery.Engine`.
  """
  def touch_test_dispatched_at(%WebhookChannel{id: id} = channel, %DateTime{} = now) do
    Tenant.with_workspace!(channel.workspace_id, fn ->
      WebhookChannel
      |> where([w], w.id == ^id)
      |> Repo.update_all(set: [last_test_dispatched_at: now, updated_at: now])

      :ok
    end)
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
