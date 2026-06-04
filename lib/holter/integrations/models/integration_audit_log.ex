defmodule Holter.Integrations.Models.IntegrationAuditLog do
  @moduledoc """
  Append-only audit trail owned by the Integrations context: who connected,
  disconnected, or configured an integration, and which actions the system
  dispatched. Workspace-scoped (RLS); never written through another context.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Holter.Identity.Models.User
  alias Holter.Monitoring.Models.Workspace

  @actor_types ~w(user system)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "integration_audit_logs" do
    field :actor_type, :string
    field :resource, :string
    field :action, :string
    field :diff, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    belongs_to :actor, User, foreign_key: :actor_id
    belongs_to :workspace, Workspace

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def actor_types, do: @actor_types

  def insert_changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :actor_id,
      :actor_type,
      :workspace_id,
      :resource,
      :action,
      :diff,
      :occurred_at
    ])
    |> validate_required([:actor_type, :workspace_id, :resource, :action, :occurred_at])
    |> validate_inclusion(:actor_type, @actor_types)
    |> validate_actor_id_matches_type()
    |> foreign_key_constraint(:actor_id)
    |> foreign_key_constraint(:workspace_id)
    |> check_constraint(:actor_type, name: :actor_type_known)
  end

  defp validate_actor_id_matches_type(changeset) do
    actor_type = get_field(changeset, :actor_type)
    actor_id = get_field(changeset, :actor_id)
    validate_actor_type_rules(changeset, actor_type, actor_id)
  end

  defp validate_actor_type_rules(changeset, "system", actor_id) when not is_nil(actor_id),
    do: add_error(changeset, :actor_id, "must be null when actor_type is system")

  defp validate_actor_type_rules(changeset, "user", nil),
    do: add_error(changeset, :actor_id, "must be present when actor_type is user")

  defp validate_actor_type_rules(changeset, _type, _actor_id), do: changeset
end
