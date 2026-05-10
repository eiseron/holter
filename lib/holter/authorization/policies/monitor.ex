defmodule Holter.Authorization.Policies.Monitor do
  @moduledoc """
  Authorization policy for `Holter.Monitoring.Monitor`.

  Resolves the parent workspace from either an instance subject
  (`%Monitor{workspace_id: ...}`) or an intent tuple
  (`{Monitor, %Workspace{}}`) and delegates the role question to
  `Holter.Identity.Memberships`.

  | action     | minimum role |
  | ---------- | ------------ |
  | `:read`    | member       |
  | `:write`   | member       |
  | `:delete`  | admin        |

  `:admin` and `:destroy` are not modelled for monitors: they belong to
  the workspace itself and live in a separate policy.
  """

  @behaviour Holter.Authorization.Policy

  alias Holter.Identity.Memberships
  alias Holter.Identity.User
  alias Holter.Monitoring.{Monitor, Workspace}

  @impl true
  def can?(%User{} = user, action, %Monitor{workspace_id: workspace_id}) do
    workspace_role_check(user, action, %Workspace{id: workspace_id})
  end

  def can?(%User{} = user, action, {Monitor, %Workspace{} = workspace}) do
    workspace_role_check(user, action, workspace)
  end

  def can?(_user, _action, _subject), do: false

  @impl true
  def scope_for(:read), do: "read:monitors"
  def scope_for(:write), do: "write:monitors"
  def scope_for(:delete), do: "write:monitors"
  def scope_for(_action), do: nil

  defp workspace_role_check(user, action, workspace) when action in [:read, :write] do
    Memberships.member?(user, workspace)
  end

  defp workspace_role_check(user, :delete, workspace) do
    Memberships.admin?(user, workspace)
  end

  defp workspace_role_check(_user, _action, _workspace), do: false
end
