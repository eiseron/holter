defmodule Holter.System.Models.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Holter.Identity.Models.User

  @actor_types ~w(admin system)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "audit_logs" do
    field :actor_type, :string
    field :resource, :string
    field :action, :string
    field :diff, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    belongs_to :actor, User, foreign_key: :actor_id

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def actor_types, do: @actor_types

  def insert_changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:actor_id, :actor_type, :resource, :action, :diff, :occurred_at])
    |> validate_required([:actor_type, :resource, :action, :occurred_at])
    |> validate_inclusion(:actor_type, @actor_types)
    |> validate_actor_id_matches_type()
    |> foreign_key_constraint(:actor_id)
    |> check_constraint(:actor_type, name: :actor_type_known)
  end

  defp validate_actor_id_matches_type(changeset) do
    actor_type = get_field(changeset, :actor_type)
    actor_id = get_field(changeset, :actor_id)

    cond do
      actor_type == "system" and not is_nil(actor_id) ->
        add_error(changeset, :actor_id, "must be null when actor_type is system")

      actor_type == "admin" and is_nil(actor_id) ->
        add_error(changeset, :actor_id, "must be present when actor_type is admin")

      true ->
        changeset
    end
  end
end
