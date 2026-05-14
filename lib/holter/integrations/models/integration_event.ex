defmodule Holter.Integrations.Models.IntegrationEvent do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @directions ~w(outbound inbound)a
  @statuses ~w(success failed rate_limited retried)a

  schema "integration_events" do
    field :direction, Ecto.Enum, values: @directions
    field :action, :string
    field :target, :string
    field :payload_redacted, :map, default: %{}
    field :status, Ecto.Enum, values: @statuses
    field :duration_ms, :integer
    field :occurred_at, :utc_datetime

    belongs_to :integration, Holter.Integrations.Models.Integration

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def directions, do: @directions
  def statuses, do: @statuses

  def insert_changeset(event, attrs) do
    event
    |> cast(attrs, [
      :integration_id,
      :direction,
      :action,
      :target,
      :payload_redacted,
      :status,
      :duration_ms,
      :occurred_at
    ])
    |> validate_required([:integration_id, :direction, :action, :status, :occurred_at])
    |> validate_length(:action, min: 1, max: 255)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:integration_id)
  end
end
