defmodule Holter.Delivery.Models.EmailChannel do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Holter.I18n.Locale

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @unambiguous_alphabet ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

  schema "email_channels" do
    field :name, :string
    field :settings, :map, default: %{}
    field :anti_phishing_code, :string
    field :last_test_dispatched_at, :utc_datetime
    field :locale, :string

    belongs_to :workspace, Holter.Monitoring.Models.Workspace

    has_many :recipients, Holter.Delivery.Models.EmailChannelRecipient

    timestamps(type: :utc_datetime)
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [:workspace_id, :name, :settings, :locale])
    |> validate_required([:workspace_id, :name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_locale()
    |> ensure_anti_phishing_code()
    |> foreign_key_constraint(:workspace_id)
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

  defp validate_locale(changeset) do
    validate_change(changeset, :locale, fn :locale, value ->
      cond do
        is_nil(value) -> []
        Locale.valid?(value) -> []
        true -> [locale: "is not a supported locale"]
      end
    end)
  end
end
