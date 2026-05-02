defmodule Holter.Identity.WorkspaceMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @roles [:owner, :admin, :member]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "workspace_memberships" do
    field :role, Ecto.Enum, values: @roles, default: :member

    belongs_to :user, Holter.Identity.User
    belongs_to :workspace, Holter.Monitoring.Workspace

    timestamps(type: :utc_datetime)
  end

  def roles, do: @roles

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :workspace_id, :role])
    |> validate_required([:user_id, :workspace_id, :role])
    |> assoc_constraint(:user)
    |> assoc_constraint(:workspace)
    |> unique_constraint([:user_id, :workspace_id],
      name: :workspace_memberships_user_id_workspace_id_index,
      message: "is already a member of this workspace"
    )
  end
end
