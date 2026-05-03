defmodule Holter.Identity.Memberships do
  @moduledoc """
  Coordinator for workspace memberships. Owns DB writes and reads
  for the join between Identity users and Monitoring workspaces.
  """

  import Ecto.Query

  alias Holter.Identity.WorkspaceMembership
  alias Holter.Monitoring
  alias Holter.Monitoring.Workspace
  alias Holter.Repo

  def create_default_membership(%{id: user_id}, %{id: workspace_id}) do
    %WorkspaceMembership{}
    |> WorkspaceMembership.changeset(%{
      user_id: user_id,
      workspace_id: workspace_id,
      role: :owner
    })
    |> Repo.insert()
  end

  def member?(%{id: user_id}, %{id: workspace_id}) do
    Repo.exists?(
      from m in WorkspaceMembership,
        where: m.user_id == ^user_id and m.workspace_id == ^workspace_id
    )
  end

  def fetch_workspace_for_member(user, workspace_id) when is_binary(workspace_id) do
    with {:ok, workspace} <- Monitoring.get_workspace(workspace_id),
         true <- member?(user, workspace) do
      {:ok, workspace}
    end
  end

  def list_workspaces_for_user(%{id: user_id}) do
    Repo.all(
      from w in Workspace,
        join: m in WorkspaceMembership,
        on: m.workspace_id == w.id,
        where: m.user_id == ^user_id,
        order_by: [asc: m.inserted_at]
    )
  end
end
