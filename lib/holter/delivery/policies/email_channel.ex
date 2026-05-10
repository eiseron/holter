defmodule Holter.Delivery.Policies.EmailChannel do
  @moduledoc """
  Authorization policy for `Holter.Delivery.Models.EmailChannel`.

  | action    | minimum role |
  | --------- | ------------ |
  | `:read`   | member       |
  | `:create` | member       |
  | `:update` | member       |
  | `:delete` | admin        |

  For `:create`, the subject is the parent `%Workspace{}`. For the other
  actions, it is the `%EmailChannel{}` itself. Recipient verification
  uses a one-time token and bypasses this policy.
  """

  @behaviour Bodyguard.Policy

  import Ecto.Query, only: [from: 2]

  alias Holter.Delivery.Models.EmailChannel
  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.User
  alias Holter.Monitoring.Models.Workspace

  @doc """
  Filters an EmailChannel query down to channels in workspaces the user
  can access.
  """
  def scope(query, %User{} = user) do
    from c in query,
      where: c.workspace_id in subquery(Memberships.accessible_workspace_ids_subquery(user))
  end

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(action, %User{} = user, %EmailChannel{workspace_id: workspace_id})
      when action in [:read, :update] do
    require_role(user, %Workspace{id: workspace_id}, :member)
  end

  def authorize(:delete, %User{} = user, %EmailChannel{workspace_id: workspace_id}) do
    require_role(user, %Workspace{id: workspace_id}, :admin)
  end

  def authorize(:create, %User{} = user, %Workspace{} = workspace) do
    require_role(user, workspace, :member)
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}

  defp require_role(user, workspace, :member) do
    if Memberships.member?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end

  defp require_role(user, workspace, :admin) do
    if Memberships.admin?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end
end
