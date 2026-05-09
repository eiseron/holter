defmodule Holter.Identity.Memberships do
  @moduledoc """
  Coordinator for workspace memberships. Owns DB writes and reads for
  the join between Identity users and Monitoring workspaces.

  Membership rows enforce RLS keyed on `app.current_user_id` — the
  acting user can only see and write rows whose `user_id` matches the
  session variable. Every entry point here is called from a context
  where the user has already been resolved (registration, auth hooks,
  post-login landing), so each one wraps its DB work in
  `Holter.Repo.Tenant.with_user!/2`.
  """

  import Ecto.Query

  alias Holter.Identity.WorkspaceMembership
  alias Holter.Monitoring
  alias Holter.Monitoring.Workspace
  alias Holter.Repo
  alias Holter.Repo.Tenant

  def create_default_membership(%{id: user_id} = user, %{id: workspace_id}) do
    Tenant.with_user!(user, fn ->
      %WorkspaceMembership{}
      |> WorkspaceMembership.changeset(%{
        user_id: user_id,
        workspace_id: workspace_id,
        role: :owner
      })
      |> Repo.insert()
    end)
  end

  def member?(%{id: user_id} = user, %{id: workspace_id}) do
    Tenant.with_user!(user, fn ->
      Repo.exists?(
        from m in WorkspaceMembership,
          where: m.user_id == ^user_id and m.workspace_id == ^workspace_id
      )
    end)
  end

  def admin?(%{id: user_id} = user, %{id: workspace_id}) do
    Tenant.with_user!(user, fn ->
      Repo.exists?(
        from m in WorkspaceMembership,
          where:
            m.user_id == ^user_id and
              m.workspace_id == ^workspace_id and
              m.role in [:owner, :admin]
      )
    end)
  end

  def get_membership(%{id: user_id} = user, %{id: workspace_id}) do
    Tenant.with_user!(user, fn ->
      Repo.one(
        from m in WorkspaceMembership,
          where: m.user_id == ^user_id and m.workspace_id == ^workspace_id
      )
    end)
  end

  def fetch_workspace_for_member(user, workspace_id) when is_binary(workspace_id) do
    with {:ok, workspace} <- Monitoring.get_workspace(workspace_id),
         true <- member?(user, workspace) do
      {:ok, workspace}
    end
  end

  def list_workspaces_for_user(%{id: user_id} = user) do
    Tenant.with_user!(user, fn ->
      Repo.all(
        from w in Workspace,
          join: m in WorkspaceMembership,
          on: m.workspace_id == w.id,
          where: m.user_id == ^user_id,
          order_by: [asc: m.inserted_at]
      )
    end)
  end

  def list_workspace_memberships_for_user(%{id: user_id} = user) do
    Tenant.with_user!(user, fn ->
      Repo.all(
        from m in WorkspaceMembership,
          join: w in Workspace,
          on: m.workspace_id == w.id,
          where: m.user_id == ^user_id,
          order_by: [asc: m.inserted_at],
          preload: [workspace: w]
      )
    end)
  end
end
