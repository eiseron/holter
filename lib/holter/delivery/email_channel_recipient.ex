defmodule Holter.Delivery.EmailChannelRecipient do
  @moduledoc """
  CC recipient on an email channel — its own verification token and
  state, scoped to a single `Holter.Delivery.EmailChannel`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_channel_recipients" do
    field :email, :string
    field :token, :string
    field :token_expires_at, :naive_datetime
    field :verified_at, :naive_datetime

    belongs_to :email_channel, Holter.Delivery.EmailChannel

    timestamps()
  end

  def changeset(recipient, attrs) do
    recipient
    |> cast(attrs, [:email_channel_id, :email, :token, :token_expires_at, :verified_at])
    |> validate_required([:email_channel_id, :email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_length(:email, max: 255)
    |> unique_constraint(:email,
      name: :email_channel_recipients_email_channel_id_email_index,
      message: "has already been added to this channel"
    )
  end

  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
