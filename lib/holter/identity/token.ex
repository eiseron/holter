defmodule Holter.Identity.Token do
  use Ecto.Schema
  import Ecto.Changeset

  @types [:session, :verify_email, :reset_password, :magic_link]
  @rand_size 32

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "auth_tokens" do
    field :type, Ecto.Enum, values: @types
    field :hashed_value, :binary, redact: true
    field :context, :map, default: %{}
    field :used_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, Holter.Identity.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def types, do: @types
  def rand_size, do: @rand_size

  def compute_hash(plaintext) when is_binary(plaintext) do
    :crypto.hash(:sha256, plaintext)
  end

  def expired?(%__MODULE__{expires_at: expires_at}, %DateTime{} = now) do
    DateTime.compare(expires_at, now) != :gt
  end

  def consumed?(%__MODULE__{used_at: nil}), do: false
  def consumed?(%__MODULE__{used_at: %DateTime{}}), do: true

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :type, :hashed_value, :context, :expires_at])
    |> validate_required([:user_id, :type, :hashed_value, :expires_at])
    |> assoc_constraint(:user)
    |> unique_constraint(:hashed_value)
  end

  def consume_changeset(%__MODULE__{} = token, %DateTime{} = now) do
    change(token, used_at: now)
  end
end
