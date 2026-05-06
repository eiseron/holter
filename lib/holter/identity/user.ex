defmodule Holter.Identity.User do
  use Ecto.Schema
  use Gettext, backend: HolterWeb.Gettext
  import Ecto.Changeset

  alias Holter.I18n.Locale
  alias Holter.Identity.EmailNormalizer

  @onboarding_statuses [:pending_verification, :active, :pending_billing, :banned]
  @email_format ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :hashed_password, :string, redact: true

    field :onboarding_status, Ecto.Enum,
      values: @onboarding_statuses,
      default: :pending_verification

    field :email_verified_at, :utc_datetime
    field :terms_accepted_at, :utc_datetime
    field :terms_version, :string

    field :preferred_locale, :string

    timestamps(type: :utc_datetime)
  end

  def onboarding_statuses, do: @onboarding_statuses

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :hashed_password,
      :terms_accepted_at,
      :terms_version,
      :preferred_locale
    ])
    |> validate_required([:email, :hashed_password, :terms_accepted_at, :terms_version])
    |> update_change(:email, &EmailNormalizer.normalize/1)
    |> validate_format(:email, @email_format, message: gettext("must be a valid email address"))
    |> validate_length(:email, max: 254)
    |> validate_locale(:preferred_locale)
    |> unique_constraint(:email)
  end

  def preferences_changeset(user, attrs) do
    user
    |> cast(attrs, [:preferred_locale])
    |> validate_locale(:preferred_locale)
  end

  def email_verification_changeset(user, now) do
    change(user, email_verified_at: now)
    |> maybe_activate()
  end

  defp validate_locale(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      cond do
        is_nil(value) -> []
        Locale.valid?(value) -> []
        true -> [{field, gettext("is not a supported locale")}]
      end
    end)
  end

  defp maybe_activate(changeset) do
    case get_field(changeset, :onboarding_status) do
      :pending_verification -> put_change(changeset, :onboarding_status, :active)
      _ -> changeset
    end
  end
end
