defmodule Holter.Identity.Policies.ApiToken do
  @moduledoc """
  Authorization policy for `Holter.Identity.Models.ApiToken`.

  Tokens are personal credentials: only the owning user manages them.
  Workspace admins can read and revoke tokens issued in their workspace
  to support offboarding.

  | action    | who can act                                            |
  | --------- | ------------------------------------------------------ |
  | `:read`   | the token's owner, or an admin of the workspace        |
  | `:create` | any member of the workspace (for self)                 |
  | `:revoke` | the token's owner, or an admin of the workspace        |

  For `:create`, the subject is the parent `%Workspace{}`. For the other
  actions, it is the `%ApiToken{}` itself.
  """

  @behaviour Bodyguard.Policy

  import Ecto.Query, only: [from: 2]

  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.{ApiToken, User}
  alias Holter.Monitoring.Models.Workspace

  @doc """
  Filters an ApiToken query down to tokens visible to the user. A plain
  member sees only the tokens they issued; admins and owners see every
  token in their workspaces.
  """
  def scope(query, %User{id: user_id} = user) do
    from t in query,
      where:
        t.workspace_id in subquery(Memberships.accessible_workspace_ids_subquery(user)) and
          (t.user_id == ^user_id or
             t.workspace_id in subquery(Memberships.admin_workspace_ids_subquery(user)))
  end

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(action, %User{id: user_id} = user, %ApiToken{
        user_id: token_user_id,
        workspace_id: workspace_id
      })
      when action in [:read, :revoke] do
    cond do
      user_id == token_user_id and Memberships.member?(user, %Workspace{id: workspace_id}) -> :ok
      Memberships.admin?(user, %Workspace{id: workspace_id}) -> :ok
      true -> {:error, :unauthorized}
    end
  end

  def authorize(:create, %User{} = user, %Workspace{} = workspace) do
    if Memberships.member?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}
end
