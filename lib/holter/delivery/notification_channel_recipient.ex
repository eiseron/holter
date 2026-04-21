defmodule Holter.Delivery.NotificationChannelRecipient do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_channel_recipients" do
    field :email, :string
    field :token, :string
    field :token_expires_at, :naive_datetime
    field :verified_at, :naive_datetime

    belongs_to :notification_channel, Holter.Delivery.NotificationChannel

    timestamps()
  end

  def changeset(recipient, attrs) do
    recipient
    |> cast(attrs, [:notification_channel_id, :email, :token, :token_expires_at, :verified_at])
    |> validate_required([:notification_channel_id, :email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_length(:email, max: 255)
    |> unique_constraint(:email,
      name: "notification_channel_recipients_notification_channel_id_email_i",
      message: "has already been added to this channel"
    )
  end

  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
