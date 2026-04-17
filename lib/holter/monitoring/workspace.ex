defmodule Holter.Monitoring.Workspace do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: HolterWeb.Gettext

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @trigger_short_window_seconds 60
  @trigger_long_window_seconds 3600
  @create_short_window_seconds 60
  @create_long_window_seconds 3600

  def trigger_short_window_seconds, do: @trigger_short_window_seconds
  def trigger_long_window_seconds, do: @trigger_long_window_seconds
  def create_short_window_seconds, do: @create_short_window_seconds
  def create_long_window_seconds, do: @create_long_window_seconds

  schema "workspaces" do
    field :name, :string
    field :slug, :string

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

    has_many :monitors, Holter.Monitoring.Monitor

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [
      :name,
      :slug,
      :retention_days,
      :max_monitors,
      :min_interval_seconds,
      :last_check_triggered_at,
      :max_triggers_per_minute,
      :max_triggers_per_hour,
      :max_creates_per_minute,
      :max_creates_per_hour
    ])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> validate_required([:slug, :retention_days, :max_monitors, :min_interval_seconds])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:retention_days, greater_than_or_equal_to: 1)
    |> validate_number(:max_monitors, greater_than_or_equal_to: 1)
    |> validate_number(:min_interval_seconds, greater_than_or_equal_to: 10)
    |> validate_number(:max_triggers_per_minute, greater_than_or_equal_to: 1)
    |> validate_number(:max_triggers_per_hour, greater_than_or_equal_to: 1)
    |> validate_number(:max_creates_per_minute, greater_than_or_equal_to: 1)
    |> validate_number(:max_creates_per_hour, greater_than_or_equal_to: 1)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/,
      message: "must be 3-63 lowercase alphanumeric characters or hyphens"
    )
    |> validate_slug_immutability()
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case {get_field(changeset, :slug), get_change(changeset, :name)} do
      {nil, name} when is_binary(name) ->
        put_change(changeset, :slug, slugify(name))

      _ ->
        changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> String.slice(0, 63)
  end

  defp validate_slug_immutability(changeset) do
    if changeset.data.id && get_change(changeset, :slug) do
      add_error(changeset, :slug, gettext("cannot be changed after creation"))
    else
      changeset
    end
  end
end
