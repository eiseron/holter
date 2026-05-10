defmodule Holter.Monitoring.Policies.Workspace do
  @moduledoc """
  Authorization policy for `Holter.Monitoring.Models.Workspace`.

  | action    | minimum role               |
  | --------- | -------------------------- |
  | `:read`   | member                     |
  | `:create` | any authenticated user     |
  | `:update` | admin                      |
  | `:delete` | owner                      |

  Subject is the `%Workspace{}`; `nil` for `:create`.
  """

  @behaviour Bodyguard.Policy

  import Ecto.Query, only: [from: 2]

  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.User
  alias Holter.Monitoring.Models.Workspace

  @doc """
  Filters a Workspace query down to workspaces the user is a member of.
  """
  def scope(query, %User{} = user) do
    from w in query,
      where: w.id in subquery(Memberships.accessible_workspace_ids_subquery(user))
  end

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(:create, %User{}, _subject), do: :ok

  def authorize(:read, %User{} = user, %Workspace{} = workspace) do
    if Memberships.member?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end

  def authorize(:update, %User{} = user, %Workspace{} = workspace) do
    if Memberships.admin?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end

  def authorize(:delete, %User{} = user, %Workspace{} = workspace) do
    if Memberships.owner?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}
end
