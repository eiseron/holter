defmodule Holter.Monitoring.Models.WorkspaceProfile do
  use Ecto.Schema

  import Ecto.Changeset

  alias Holter.Monitoring.Models.Workspace

  @primary_key false
  @foreign_key_type :binary_id

  @trigger_short_window_seconds 60
  @trigger_long_window_seconds 3600
  @create_short_window_seconds 60
  @create_long_window_seconds 3600

  def trigger_short_window_seconds, do: @trigger_short_window_seconds
  def trigger_long_window_seconds, do: @trigger_long_window_seconds
  def create_short_window_seconds, do: @create_short_window_seconds
  def create_long_window_seconds, do: @create_long_window_seconds

  schema "monitoring_workspace_profiles" do
    belongs_to :workspace, Workspace, primary_key: true

    field :retention_days, :integer, default: 3
    field :max_monitors, :integer, default: 3
    field :min_interval_seconds, :integer, default: 600
    field :last_check_triggered_at, :utc_datetime

    field :max_triggers_per_minute, :integer, default: 3
    field :max_triggers_per_hour, :integer, default: 20
    field :trigger_short_count, :integer, default: 0
    field :trigger_short_window_start, :utc_datetime
    field :trigger_long_count, :integer, default: 0
    field :trigger_long_window_start, :utc_datetime

    field :max_creates_per_minute, :integer, default: 5
    field :max_creates_per_hour, :integer, default: 20
    field :create_short_count, :integer, default: 0
    field :create_short_window_start, :utc_datetime
    field :create_long_count, :integer, default: 0
    field :create_long_window_start, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :workspace_id,
      :retention_days,
      :max_monitors,
      :min_interval_seconds,
      :last_check_triggered_at,
      :max_triggers_per_minute,
      :max_triggers_per_hour,
      :max_creates_per_minute,
      :max_creates_per_hour
    ])
    |> validate_required([
      :workspace_id,
      :retention_days,
      :max_monitors,
      :min_interval_seconds
    ])
    |> validate_number(:retention_days, greater_than_or_equal_to: 1)
    |> validate_number(:max_monitors, greater_than_or_equal_to: 1)
    |> validate_number(:min_interval_seconds, greater_than_or_equal_to: 10)
    |> validate_number(:max_triggers_per_minute, greater_than_or_equal_to: 1)
    |> validate_number(:max_triggers_per_hour, greater_than_or_equal_to: 1)
    |> validate_number(:max_creates_per_minute, greater_than_or_equal_to: 1)
    |> validate_number(:max_creates_per_hour, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:workspace_id)
  end
end
