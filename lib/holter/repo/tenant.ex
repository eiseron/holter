defmodule Holter.Repo.Tenant do
  @moduledoc """
  Coordinator for the per-connection RLS session variables. Owns every
  `set_config` call against the database.

  Two independent variables back the policies:

    * `app.current_user_id` — keyed by `with_user/2`. Used by tables
      whose RLS predicate scopes to the calling user (e.g.
      `workspace_memberships`).
    * `app.current_workspace_id` — keyed by `with_workspace/2`. Used by
      every other workspace-scoped table.

  No admin / BYPASSRLS path exists in the application: the runtime DB
  user is granted membership in `holter_app` only. Cross-workspace
  background work iterates the (global) `workspaces` table and calls
  `with_workspace/2` per row.
  """

  alias Eiseron.Identity.Tenant
  alias Holter.Repo

  @spec with_workspace(term(), (-> result)) :: result when result: term()
  def with_workspace(workspace_id, fun) when is_function(fun, 0) do
    case Tenant.parse_workspace_id(workspace_id) do
      {:ok, uuid} ->
        Repo.checkout(fn ->
          previous = current_workspace_id()
          stamp(Tenant.workspace_session_var(), uuid)

          try do
            fun.()
          after
            stamp(Tenant.workspace_session_var(), previous || "")
          end
        end)

      {:error, :invalid_workspace_id} ->
        raise ArgumentError,
              "Holter.Repo.Tenant.with_workspace/2 requires a workspace id; got: " <>
                inspect(workspace_id)
    end
  end

  @spec with_user(term(), (-> result)) :: result when result: term()
  def with_user(user_id, fun) when is_function(fun, 0) do
    case Tenant.parse_user_id(user_id) do
      {:ok, uuid} ->
        Repo.checkout(fn ->
          previous = current_user_id()
          stamp(Tenant.user_session_var(), uuid)

          try do
            fun.()
          after
            stamp(Tenant.user_session_var(), previous || "")
          end
        end)

      {:error, :invalid_user_id} ->
        raise ArgumentError,
              "Holter.Repo.Tenant.with_user/2 requires a user id; got: " <>
                inspect(user_id)
    end
  end

  @spec with_workspace!(term(), (-> result)) :: result when result: term()
  def with_workspace!(workspace_id, fun), do: with_workspace(workspace_id, fun)

  @spec with_user!(term(), (-> result)) :: result when result: term()
  def with_user!(user_id, fun), do: with_user(user_id, fun)

  @spec current_workspace_id() :: String.t() | nil
  def current_workspace_id, do: read_session_var(Tenant.workspace_session_var())

  @spec current_user_id() :: String.t() | nil
  def current_user_id, do: read_session_var(Tenant.user_session_var())

  defp read_session_var(name) do
    %{rows: [[value]]} = Repo.query!("SELECT current_setting($1, true)", [name])

    case value do
      "" -> nil
      nil -> nil
      uuid -> uuid
    end
  end

  defp stamp(name, value) do
    Repo.query!("SELECT set_config($1, $2, false)", [name, value])
  end
end
