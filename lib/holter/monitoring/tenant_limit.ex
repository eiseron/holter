defmodule Holter.Monitoring.TenantLimit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:user_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "tenant_limits" do
    field :retention_days, :integer, default: 3
    field :max_monitors, :integer, default: 3
    field :min_interval_seconds, :integer, default: 600

    belongs_to :organization, Holter.Monitoring.Organization

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenant_limit, attrs) do
    tenant_limit
    |> cast(attrs, [:user_id, :retention_days, :max_monitors, :min_interval_seconds])
    |> validate_required([:user_id, :retention_days, :max_monitors, :min_interval_seconds])
    |> validate_number(:retention_days, greater_than_or_equal_to: 1)
    |> validate_number(:max_monitors, greater_than_or_equal_to: 1)
    |> validate_number(:min_interval_seconds, greater_than_or_equal_to: 10)
  end
end
