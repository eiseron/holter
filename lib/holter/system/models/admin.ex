defmodule Holter.System.Models.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  alias Holter.Identity.Models.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admins" do
    field :promoted_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, User
    belongs_to :promoted_by, __MODULE__, foreign_key: :promoted_by_admin_id
    belongs_to :revoked_by, __MODULE__, foreign_key: :revoked_by_admin_id

    timestamps(type: :utc_datetime)
  end

  def promotion_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:user_id, :promoted_by_admin_id, :promoted_at])
    |> validate_required([:user_id, :promoted_at])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:promoted_by_admin_id)
    |> unique_constraint(:user_id, name: :admins_user_id_active_index)
  end

  def revocation_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:revoked_at, :revoked_by_admin_id])
    |> validate_required([:revoked_at, :revoked_by_admin_id])
    |> foreign_key_constraint(:revoked_by_admin_id)
  end
end
