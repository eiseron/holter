defmodule Holter.Delivery.NotificationChannel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Holter.Delivery.{EmailChannel, WebhookChannel}

  @channel_types [:email, :webhook]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notification_channels" do
    field :name, :string

    field :type, Ecto.Enum, values: @channel_types, virtual: true
    field :target, :string, virtual: true
    field :settings, :map, virtual: true, default: %{}

    belongs_to :workspace, Holter.Monitoring.Workspace

    has_one :webhook_channel, WebhookChannel, on_replace: :delete
    has_one :email_channel, EmailChannel, on_replace: :delete

    many_to_many :monitors, Holter.Monitoring.Monitor,
      join_through: Holter.Delivery.MonitorNotification,
      join_keys: [notification_channel_id: :id, monitor_id: :id]

    has_many :recipients, Holter.Delivery.NotificationChannelRecipient

    timestamps(type: :utc_datetime)
  end

  def channel_types, do: @channel_types

  @doc """
  Returns the channel type derived from the loaded subtype association.

  Requires that `:webhook_channel` and `:email_channel` are preloaded.
  """
  def type(%__MODULE__{webhook_channel: %WebhookChannel{}}), do: :webhook
  def type(%__MODULE__{email_channel: %EmailChannel{}}), do: :email
  def type(%__MODULE__{type: type}) when type in @channel_types, do: type
  def type(%__MODULE__{}), do: nil

  @doc """
  Returns the channel target derived from the loaded subtype association.
  """
  def target(%__MODULE__{webhook_channel: %WebhookChannel{url: url}}), do: url
  def target(%__MODULE__{email_channel: %EmailChannel{address: address}}), do: address
  def target(%__MODULE__{target: target}), do: target

  @doc """
  Returns the channel settings map derived from the loaded subtype association.
  """
  def settings(%__MODULE__{webhook_channel: %WebhookChannel{settings: settings}}), do: settings
  def settings(%__MODULE__{email_channel: %EmailChannel{settings: settings}}), do: settings
  def settings(%__MODULE__{settings: settings}) when is_map(settings), do: settings
  def settings(%__MODULE__{}), do: %{}

  @doc """
  Hydrates the virtual `:type`, `:target` and `:settings` fields on a
  notification channel struct from its loaded subtype, so callers can
  read them directly without going through the helpers above.

  No-op when the subtype isn't preloaded.
  """
  def populate_virtuals(%__MODULE__{webhook_channel: %WebhookChannel{} = w} = channel) do
    %{channel | type: :webhook, target: w.url, settings: w.settings}
  end

  def populate_virtuals(%__MODULE__{email_channel: %EmailChannel{} = e} = channel) do
    %{channel | type: :email, target: e.address, settings: e.settings}
  end

  def populate_virtuals(%__MODULE__{} = channel), do: channel

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:workspace_id, :name, :type, :target, :settings])
    |> validate_required([:workspace_id, :name, :type, :target])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:target, min: 1, max: 2048)
    |> foreign_key_constraint(:workspace_id)
    |> put_subtype_assoc()
  end

  defp put_subtype_assoc(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp put_subtype_assoc(changeset) do
    type = get_field(changeset, :type)
    target = get_field(changeset, :target)
    settings = get_field(changeset, :settings) || %{}

    case type do
      :webhook ->
        existing = existing_subtype(changeset.data, :webhook_channel, %WebhookChannel{})
        sub_changeset = WebhookChannel.changeset(existing, %{url: target, settings: settings})

        changeset
        |> put_assoc(:webhook_channel, sub_changeset)
        |> propagate_subtype_errors(sub_changeset, {:url, :target})

      :email ->
        existing = existing_subtype(changeset.data, :email_channel, %EmailChannel{})
        sub_changeset = EmailChannel.changeset(existing, %{address: target, settings: settings})

        changeset
        |> put_assoc(:email_channel, sub_changeset)
        |> propagate_subtype_errors(sub_changeset, {:address, :target})

      _ ->
        changeset
    end
  end

  defp existing_subtype(%__MODULE__{} = data, key, fallback) do
    case Map.get(data, key) do
      %WebhookChannel{} = w -> w
      %EmailChannel{} = e -> e
      _ -> fallback
    end
  end

  defp propagate_subtype_errors(parent_cs, sub_cs, {source_key, target_key}) do
    sub_cs.errors
    |> Enum.filter(fn {key, _} -> key == source_key end)
    |> Enum.reduce(parent_cs, fn {_, {msg, opts}}, acc ->
      add_error(acc, target_key, msg, opts)
    end)
  end
end
