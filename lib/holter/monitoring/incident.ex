defmodule Holter.Monitoring.Incident do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "incidents" do
    field :type, Ecto.Enum, values: [:downtime, :defacement, :ssl_expiry]
    field :started_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :duration_seconds, :integer
    field :root_cause, :string
    field :monitor_snapshot, :map

    belongs_to :monitor, Holter.Monitoring.Monitor

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(incident, attrs) do
    incident
    |> cast(attrs, [
      :monitor_id,
      :type,
      :started_at,
      :resolved_at,
      :duration_seconds,
      :root_cause,
      :monitor_snapshot
    ])
    |> validate_required([:monitor_id, :type, :started_at])
  end
end
