defmodule Holter.Delivery.NotificationChannel do
  use Ecto.Schema
  import Ecto.Changeset

  @channel_types [:email, :webhook]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notification_channels" do
    field :name, :string
    field :type, Ecto.Enum, values: @channel_types
    field :target, :string
    field :settings, :map, default: %{}

    belongs_to :workspace, Holter.Monitoring.Workspace

    many_to_many :monitors, Holter.Monitoring.Monitor,
      join_through: Holter.Delivery.MonitorNotification,
      join_keys: [notification_channel_id: :id, monitor_id: :id]

    timestamps(type: :utc_datetime)
  end

  def channel_types, do: @channel_types

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:workspace_id, :name, :type, :target, :settings])
    |> validate_required([:workspace_id, :name, :type, :target])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:target, min: 1, max: 2048)
    |> validate_target_format()
    |> foreign_key_constraint(:workspace_id)
  end

  defp validate_target_format(changeset) do
    case get_field(changeset, :type) do
      :webhook -> validate_target_url(changeset)
      :email -> validate_target_email(changeset)
      _ -> changeset
    end
  end

  defp validate_target_url(changeset) do
    validate_change(changeset, :target, fn :target, target ->
      if valid_http_url?(target), do: [], else: [target: "must be a valid http or https URL"]
    end)
  end

  defp validate_target_email(changeset) do
    validate_change(changeset, :target, fn :target, target ->
      if String.match?(target, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/),
        do: [],
        else: [target: "must be a valid email address"]
    end)
  end

  defp valid_http_url?(target) do
    case URI.parse(target) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        true

      _ ->
        false
    end
  end
end
