defmodule Holter.Delivery.NotificationChannelLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notification_channel_logs" do
    field :status, Ecto.Enum, values: [:success, :failed]
    field :event_type, :string
    field :error_message, :string
    field :dispatched_at, :utc_datetime_usec

    belongs_to :notification_channel, Holter.Delivery.NotificationChannel
    belongs_to :monitor, Holter.Monitoring.Monitor
    belongs_to :incident, Holter.Monitoring.Incident

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :notification_channel_id,
      :status,
      :event_type,
      :error_message,
      :monitor_id,
      :incident_id,
      :dispatched_at
    ])
    |> validate_required([:notification_channel_id, :status, :event_type, :dispatched_at])
    |> validate_inclusion(:event_type, ["down", "up", "test"])
    |> foreign_key_constraint(:notification_channel_id)
    |> foreign_key_constraint(:monitor_id)
    |> foreign_key_constraint(:incident_id)
  end
end
