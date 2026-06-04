defmodule Holter.Monitoring.Models.Incident do
  use Ecto.Schema
  import Ecto.Changeset

  @types [:downtime, :defacement, :ssl_expiry, :domain_expiry]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "incidents" do
    field :type, Ecto.Enum, values: @types
    field :started_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :duration_seconds, :integer
    field :root_cause, :string
    field :monitor_snapshot, :map
    field :workspace_id, :binary_id, virtual: true

    belongs_to :monitor, Holter.Monitoring.Models.Monitor

    timestamps(type: :utc_datetime)
  end

  def types, do: @types

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
      :monitor_snapshot,
      :workspace_id
    ])
    |> validate_required([:monitor_id, :type, :started_at])
    |> unique_constraint([:monitor_id, :type],
      where: "resolved_at IS NULL",
      name: :unique_open_incident_per_type
    )
  end
end
