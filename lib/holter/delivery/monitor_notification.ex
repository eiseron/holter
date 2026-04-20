defmodule Holter.Delivery.MonitorNotification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id
  schema "monitor_notifications" do
    belongs_to :monitor, Holter.Monitoring.Monitor
    belongs_to :notification_channel, Holter.Delivery.NotificationChannel

    field :is_active, :boolean, default: true
    field :inserted_at, :utc_datetime
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:monitor_id, :notification_channel_id, :is_active])
    |> validate_required([:monitor_id, :notification_channel_id])
    |> foreign_key_constraint(:monitor_id)
    |> foreign_key_constraint(:notification_channel_id)
    |> unique_constraint([:monitor_id, :notification_channel_id])
  end
end
