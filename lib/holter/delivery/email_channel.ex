defmodule Holter.Delivery.EmailChannel do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @unambiguous_alphabet ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

  schema "email_channels" do
    field :address, :string
    field :settings, :map, default: %{}
    field :anti_phishing_code, :string

    belongs_to :notification_channel, Holter.Delivery.NotificationChannel

    timestamps(type: :utc_datetime)
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [:notification_channel_id, :address, :settings])
    |> validate_required([:address])
    |> validate_length(:address, min: 1, max: 2048)
    |> validate_email_format()
    |> ensure_anti_phishing_code()
    |> unique_constraint(:notification_channel_id)
    |> foreign_key_constraint(:notification_channel_id)
  end

  def generate_anti_phishing_code do
    len = length(@unambiguous_alphabet)

    chars =
      for <<b <- :crypto.strong_rand_bytes(8)>>,
        do: Enum.at(@unambiguous_alphabet, rem(b, len))

    {a, b} = Enum.split(chars, 4)
    "#{List.to_string(a)}-#{List.to_string(b)}"
  end

  defp ensure_anti_phishing_code(changeset) do
    case get_field(changeset, :anti_phishing_code) do
      nil -> put_change(changeset, :anti_phishing_code, generate_anti_phishing_code())
      _ -> changeset
    end
  end

  defp validate_email_format(changeset) do
    validate_change(changeset, :address, fn :address, address ->
      if String.match?(address, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/),
        do: [],
        else: [address: "must be a valid email address"]
    end)
  end
end
