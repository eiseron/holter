defmodule Holter.Identity.Models.ApiToken do
  use Ecto.Schema

  import Ecto.Changeset

  alias Eiseron.Identity.Scopes

  @rand_size 32
  @plaintext_prefix "hk_"
  @name_max 64

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_tokens" do
    field :name, :string
    field :hashed_value, :binary, redact: true
    field :scopes, {:array, :string}
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, Holter.Identity.Models.User
    belongs_to :workspace, Holter.Monitoring.Models.Workspace

    timestamps(type: :utc_datetime)
  end

  def rand_size, do: @rand_size
  def plaintext_prefix, do: @plaintext_prefix

  def compute_hash(plaintext) when is_binary(plaintext) do
    :crypto.hash(:sha256, plaintext)
  end

  def active?(%__MODULE__{revoked_at: revoked_at, expires_at: expires_at}, %DateTime{} = now) do
    is_nil(revoked_at) and not_expired?(expires_at, now)
  end

  def has_scope?(%__MODULE__{scopes: scopes}, scope) when is_binary(scope) do
    scope in scopes
  end

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :workspace_id, :name, :hashed_value, :scopes, :expires_at])
    |> validate_required([:user_id, :workspace_id, :name, :hashed_value])
    |> validate_length(:name, min: 1, max: @name_max)
    |> validate_scopes()
    |> assoc_constraint(:user)
    |> assoc_constraint(:workspace)
    |> unique_constraint(:hashed_value)
  end

  def revoke_changeset(%__MODULE__{} = token, %DateTime{} = now) do
    change(token, revoked_at: now)
  end

  defp not_expired?(nil, _now), do: true

  defp not_expired?(%DateTime{} = expires_at, %DateTime{} = now) do
    DateTime.compare(expires_at, now) == :gt
  end

  defp validate_scopes(changeset) do
    case get_field(changeset, :scopes) do
      empty when empty in [nil, []] ->
        add_error(changeset, :scopes, "must include at least one scope")

      scopes when is_list(scopes) ->
        case Enum.reject(scopes, &Scopes.valid?/1) do
          [] ->
            changeset

          invalid ->
            add_error(
              changeset,
              :scopes,
              "contains invalid scopes: #{Enum.join(invalid, ", ")}"
            )
        end

      _ ->
        add_error(changeset, :scopes, "must be a list of strings")
    end
  end
end
