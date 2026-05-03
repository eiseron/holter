defmodule Holter.Delivery.MonitorWebhookChannel do
  @moduledoc """
  Join row binding a monitor to a webhook channel.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id
  schema "monitor_webhook_channels" do
    belongs_to :monitor, Holter.Monitoring.Monitor
    belongs_to :webhook_channel, Holter.Delivery.WebhookChannel

    field :is_active, :boolean, default: true
    field :inserted_at, :utc_datetime
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:monitor_id, :webhook_channel_id, :is_active, :inserted_at])
    |> validate_required([:monitor_id, :webhook_channel_id])
    |> put_inserted_at()
    |> foreign_key_constraint(:monitor_id)
    |> foreign_key_constraint(:webhook_channel_id)
    |> unique_constraint([:monitor_id, :webhook_channel_id])
  end

  defp put_inserted_at(changeset) do
    if get_field(changeset, :inserted_at) do
      changeset
    else
      put_change(changeset, :inserted_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end
end
